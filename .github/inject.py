"""Inyecta secrets de GitHub Actions en los archivos del dist antes de publicar."""
import os
import sys

required = ['WA_NUMBER', 'MENU_TOKEN']
secrets = {}

for key in required:
    val = os.environ.get(key, '')
    if not val:
        print(f'ERROR: secret {key} is not set or is empty', file=sys.stderr)
        sys.exit(1)
    secrets[key] = val

replacements = {
    'dist/index.html': [
        ('__MENU_TOKEN__', secrets['MENU_TOKEN']),
    ],
    'dist/table-service.html': [
        ('__WA_NUMBER__', secrets['WA_NUMBER']),
    ],
}

for path, pairs in replacements.items():
    with open(path, encoding='utf-8') as f:
        content = f.read()
    for placeholder, value in pairs:
        if placeholder not in content:
            print(f'WARNING: {placeholder} not found in {path}', file=sys.stderr)
        content = content.replace(placeholder, value)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'OK: {path}')

print('All secrets injected.')
