# Тесты

```powershell
pwsh -File tests/run-tests.ps1
pwsh -File tests/run-tests.ps1 -Keep
```

Нужны только PowerShell 5.1+ и Git. Все fixtures создаются в `tests/.tmp`; `-Keep` сохраняет их для диагностики.

Проверяются:

- чистая установка, marked merge `config.toml`, backup и идемпотентность;
- полная замена дерева project-specifications с backup в `backups/skills`;
- минимальный initializer без hooks и четырёх обязательных документов;
- безопасные имена brief, сохранение существующих файлов и Game Master routing;
- audit patch check/apply/idempotence, защита путей и атомарный отказ при конфликте.
