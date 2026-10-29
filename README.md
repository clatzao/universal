# Universal

App Android pessoal em Flutter, todo em português: lembretes com recorrência avançada, hábitos,
notícias por RSS, clima, cotações e curiosidades. Usa só APIs gratuitas e sem chave.

**Download (sempre a versão mais recente):**
https://github.com/clatzao/universal/releases/latest/download/UniversalApp.apk

O app se atualiza sozinho (Mais → Verificar atualização). Na primeira instalação, permita
"Instalar apps desconhecidos" para o navegador.

## Desenvolvimento

```
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Sem `android/key.properties`, o build de release usa a chave de debug (só para testes locais).
No CI, a chave é recriada a partir dos secrets `ANDROID_KEYSTORE_BASE64` e
`ANDROID_KEYSTORE_PASSWORD`.
