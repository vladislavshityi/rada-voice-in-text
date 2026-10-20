<p align="center">
  <img src="docs/assets/rada.png" width="180" alt="Rada">
</p>

<h1 align="center">Rada</h1>

<p align="center">
  <b>Voice, in text.</b><br>
  Приватная диктовка для macOS: говорите, и текст появляется там, где стоит курсор.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15%2B-black?logo=apple" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Apple_Silicon-M1%2B-black" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/offline-100%25-EF5FA7" alt="Offline">
</p>

<p align="center">
  <a href="../../releases/latest"><b>Скачать последнюю версию</b></a>
</p>

---

## Как это работает

1. Нажмите **⌥ Space** в любом приложении: в Pages, Telegram, браузере, редакторе.
2. Говорите. Сверху появится Rada: маскот слушает и реагирует на голос.
3. Нажмите **⌥ Space** ещё раз. Через пару секунд текст с пунктуацией окажется в позиции курсора.

Всё происходит на вашем Mac. Аудио не сохраняется и никуда не отправляется.

## Что умеет

- **Точный русский** с английскими словами, именами и числами. Используется модель Whisper Large v3 Turbo на GPU.
- **Знаки препинания и регистр** расставляются по смыслу. Rada не переписывает речь и не добавляет слов.
- **Словарь** фамилий, организаций и терминов: `Силуанов`, `ВШЭ`, `Набиуллина` пишутся правильно.
- **Длинные диктовки без ожидания.** Законченные фразы расшифровываются, пока вы говорите. После минуты речи текст готов примерно через 2–3 секунды.
- **Голосовые команды:** «новый абзац», «новая строка».
- **Esc** отменяет запись. В поля паролей ничего не вставляется.
- Живёт в строке меню, поддерживает светлую и тёмную темы и Liquid Glass на macOS 26.

## Установка

1. Скачайте `Rada.zip` со страницы [Releases](../../releases/latest), распакуйте и перенесите **Rada.app** в «Программы».
2. Приложение подписано ad-hoc, без сертификата Apple, поэтому macOS предупредит о неизвестном разработчике. Разрешите запуск в «Системные настройки → Конфиденциальность и безопасность → Всё равно открыть» или выполните:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Rada.app
   ```
3. Rada откроет настройки с тремя шагами:
   - разрешить **микрофон**;
   - разрешить **Универсальный доступ** (чтобы вставлять текст);
   - **загрузить модель** распознавания (574 МБ, один раз).

## Конфиденциальность

- Распознавание полностью локальное. Распознавание движком Whisper проверено в песочнице с запрещённой сетью.
- Сеть используется только для загрузки модели по вашей кнопке. Файл проверяется по SHA-256.
- Аудио живёт в памяти до конца распознавания. Истории нет, аналитики и аккаунтов тоже.
- Все данные лежат в `~/Library/Application Support/Rada` и удаляются одной кнопкой.

## Сборка из исходников

Нужны Command Line Tools (`xcode-select --install`) и CMake (`brew install cmake`).

```bash
Scripts/build-whisper.sh          # whisper.cpp + Silero VAD → Vendor/
Scripts/build-app.sh --install    # Rada.app → /Applications
swift test --scratch-path ~/Library/Caches/app.rada/build
```

Устройство проекта, выбор движка и замеры описаны в [docs/how-it-works.md](docs/how-it-works.md).

## Благодарности

[whisper.cpp](https://github.com/ggml-org/whisper.cpp), [Whisper](https://github.com/openai/whisper) и [Silero VAD](https://github.com/snakers4/silero-vad) распространяются под лицензией MIT.
