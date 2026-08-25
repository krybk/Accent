#!/usr/bin/env bash
#
# Проверка, что в репозиторий не заехал секрет.
#
# Репозиторий публичный, и это меняет цену ошибки: утёкший токен шлюза — это
# рут на сервере, утёкший keystore — это возможность подписать чужой APK нашим
# ключом. Поэтому проверка стоит в CI и роняет прогон, а не предупреждает.
#
# Что она НЕ умеет: находить секрет, не похожий ни на один известный формат.
# Против этого работает .gitignore и правило «секрет генерится на целевой
# машине». Скрипт — последняя сетка, а не первая линия.
set -euo pipefail

cd "$(dirname "$0")/.."

status=0

# Известные форматы ключей. Каждая строка: <имя> <ERE-шаблон>.
# Шаблоны написаны так, чтобы не совпадать сами с собой при сканировании этого
# файла — иначе проверка падала бы на собственном исходнике.
while IFS='|' read -r label pattern; do
  [ -z "$label" ] && continue
  # git ls-files, а не рекурсивный grep: проверяем то, что реально попадёт в
  # историю, и не спотыкаемся о node_modules и target.
  if hits=$(git ls-files -z \
    | xargs -0 grep -nIE "$pattern" 2>/dev/null); then
    echo "Найден секрет ($label):"
    echo "$hits"
    status=1
  fi
done <<'PATTERNS'
OpenRouter|sk-or-v1-[0-9a-f]{40,}
Anthropic|sk-ant-[A-Za-z0-9_-]{24,}
OpenAI|sk-(proj|svcacct)-[A-Za-z0-9_-]{24,}
Google|AIza[0-9A-Za-z_-]{35}
AWS|AKIA[0-9A-Z]{16}
Приватный ключ PEM|-----BEGIN [A-Z ]*PRIVATE KEY-----
PATTERNS

# Файлы, которых в истории быть не должно ни под каким именем. Список зеркалит
# секретную часть .gitignore; расходиться им нельзя.
forbidden='(^|/)(\.env(\..*)?|id_ed25519|id_rsa|authorized_keys)$|\.(pem|jks|keystore)$'
if tracked=$(git ls-files | grep -E "$forbidden" | grep -v '\.env\.example$'); then
  echo "В индексе файлы, которые не должны версионироваться:"
  echo "$tracked"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "Секретов не найдено."
fi

exit "$status"
