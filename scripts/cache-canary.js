#!/usr/bin/env node
//
// Канарейка на кеширование промпта.
//
// Зачем. Основная статья расхода в агентном цикле — не длина ответа, а
// повторная пересылка истории на каждом вызове инструмента. Кеш снижает её
// примерно в десять раз: чтение из кеша стоит $0.20/1M против $2.00/1M входа у
// Sonnet 5. Но кеш ломается молча — любое изменение байта в префиксе, и вы
// платите полную цену, не получая ни ошибки, ни предупреждения.
//
// Что делает. Два запроса с одинаковым префиксом. Первый должен ЗАПИСАТЬ кеш,
// второй — ПРОЧИТАТЬ. Если второй читает ноль, кеш не работает, и скрипт падает.
// Точную стоимость обоих запросов берём из /api/v1/generation, а не считаем
// сами: так видно, что списал провайдер, а не что мы думаем про тарифы.
//
// Запуск: OPENROUTER_API_KEY=... node scripts/cache-canary.js [модель]

const API = 'https://openrouter.ai/api';
const MODEL = process.argv[2] || 'anthropic/claude-sonnet-5';
const KEY = process.env.OPENROUTER_API_KEY;

// Минимальный кешируемый префикс зависит от тарифа, и разница огромная.
// Замерено эмпирически на этом же скрипте, через закреплённого провайдера
// Anthropic:
//
//   Sonnet 5      кешируется от ~1024 токенов (1828 уже работали)
//   Haiku 4.5     кешируется от ~4096 токенов (3663 — нет, 4879 — да)
//
// Ниже порога кеш не создаётся МОЛЧА: ни ошибки, ни предупреждения, просто
// полная цена входа на каждом запросе. Отсюда неочевидный вывод, из-за которого
// эта константа и живёт в коде: на префиксе короче 4096 токенов Haiku не
// кешируется, и его вход по $1.00/1M выходит ДОРОЖЕ кешированного входа Sonnet
// по $0.20/1M. Haiku экономит только на длинном стабильном префиксе.
//
// Текст обязан быть побайтово одинаковым между запусками: ни даты, ни
// случайных чисел, ни счётчиков. Это то самое правило, нарушение которого
// канарейка и призвана ловить в реальных промптах.
const MIN_CACHEABLE_TOKENS = { haiku: 4096, default: 1024 };

function thresholdFor(model) {
  return /haiku/i.test(model)
    ? MIN_CACHEABLE_TOKENS.haiku
    : MIN_CACHEABLE_TOKENS.default;
}

function stablePrefix() {
  const paragraph =
    'Служебный контекст канарейки кеширования. Этот абзац существует только ' +
    'затем, чтобы префикс запроса превысил минимальный кешируемый размер и ' +
    'оставался при этом побайтово неизменным между запусками скрипта. ';
  // ~76 токенов на повтор. 64 повтора (~4880) проходят даже порог Haiku.
  // Один прогон канарейки стоит порядка полукопейки — дешевле, чем сутки
  // незамеченного отключённого кеша.
  return paragraph.repeat(64);
}

async function ask(question) {
  const res = await fetch(`${API}/v1/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${KEY}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 16,
      // Закрепление провайдера. Вопреки распространённому заблуждению, модели
      // Anthropic на OpenRouter раздаёт не один провайдер: у haiku-4.5 их
      // восемь (Anthropic, Google, Azure, Bedrock в трёх вариантах), у
      // sonnet-5 — девять. Без закрепления два соседних запроса уходят к разным
      // провайдерам, и кеш префикса не переживает переезд. Проверено: без
      // закрепления оба запроса ушли в Amazon Bedrock, с закреплением — в
      // Anthropic.
      provider: { order: ['Anthropic'], allow_fallbacks: false },
      // cache_control на системном блоке: кешируется всё до этой точки.
      // Переменная часть (вопрос) идёт ПОСЛЕ неё — иначе каждый новый вопрос
      // сдвигал бы префикс и обнулял кеш.
      system: [
        {
          type: 'text',
          text: stablePrefix(),
          cache_control: { type: 'ephemeral' },
        },
      ],
      messages: [{ role: 'user', content: question }],
    }),
  });

  const body = await res.json();
  if (body.error) throw new Error(`${MODEL}: ${body.error.message}`);
  return body;
}

// Стоимость запроса знает только провайдер: у него применены и скидка за
// чтение кеша, и наценка за запись. Свой расчёт по прайсу здесь врал бы.
async function costOf(id) {
  // Статистика появляется заметно позже самого ответа, поэтому ждём с запасом:
  // при пяти попытках по 1.5 с второй запрос стабильно оставался без цифр.
  for (let attempt = 0; attempt < 8; attempt++) {
    const res = await fetch(`${API}/v1/generation?id=${encodeURIComponent(id)}`, {
      headers: { Authorization: `Bearer ${KEY}` },
    });
    const body = await res.json();
    if (body.data) return body.data.total_cost;
    await new Promise((r) => setTimeout(r, 1500));
  }
  return null;
}

function report(label, usage, cost) {
  const write = usage.cache_creation_input_tokens ?? 0;
  const read = usage.cache_read_input_tokens ?? 0;
  const money = cost === null ? 'нет данных' : `$${cost.toFixed(6)}`;
  console.log(
    `${label}: вход ${usage.input_tokens}, запись в кеш ${write}, ` +
      `чтение из кеша ${read}, стоимость ${money}`,
  );
  return read;
}

async function main() {
  if (!KEY) {
    console.error('Нужен OPENROUTER_API_KEY.');
    process.exit(2);
  }

  console.log(`Модель: ${MODEL}`);

  // Вопросы разные, префикс один и тот же. Так проверяется именно кеш
  // префикса, а не то, что провайдер вернул готовый ответ на повторный запрос.
  const first = await ask('Ответь одним словом: раз.');
  report('Запрос 1', first.usage, await costOf(first.id));
  const written =
    (first.usage.cache_creation_input_tokens ?? 0) +
    (first.usage.cache_read_input_tokens ?? 0);

  const second = await ask('Ответь одним словом: два.');
  const secondRead = report('Запрос 2', second.usage, await costOf(second.id));

  if (secondRead > 0) {
    console.log('\nКеш работает: второй запрос прочитал префикс из кеша.');
    return;
  }

  // Два разных диагноза, и путать их нельзя. Кеш не создался — проблема в
  // запросе (порог, состав префикса). Кеш создался, но не прочитался — проблема
  // в маршрутизации или во времени жизни.
  if (written === 0) {
    console.error(
      '\nКеш НЕ создан: первый запрос не записал в кеш ни одного токена,\n' +
        'весь префикс ушёл как обычный вход по полной цене.\n' +
        `Порог для этой модели — около ${thresholdFor(MODEL)} токенов ` +
        `(у Haiku он вчетверо выше, чем у Sonnet и Opus).\n` +
        'Что проверить:\n' +
        '  — префикс короче минимального кешируемого размера для этой модели;\n' +
        '  — переменная часть стоит ДО cache_control, а не после;\n' +
        '  — cache_control вообще не доехал до провайдера.',
    );
  } else {
    console.error(
      '\nКеш создан, но НЕ прочитан: префикс записался и пропал.\n' +
        'Значит история всё равно пересылается по полной цене. Что проверить:\n' +
        '  — в префиксе есть меняющаяся часть (дата, идентификатор, счётчик);\n' +
        '  — между запросами прошло больше срока жизни кеша (по умолчанию 5 минут);\n' +
        '  — запросы ушли к разным провайдерам. Для моделей Anthropic это\n' +
        '    невозможно (провайдер один), но для открытых моделей — обычное дело:\n' +
        '    закрепите провайдера через provider.order и allow_fallbacks: false.',
    );
  }
  process.exit(1);
}

main().catch((err) => {
  console.error(`Канарейка не смогла выполнить проверку: ${err.message}`);
  process.exit(2);
});
