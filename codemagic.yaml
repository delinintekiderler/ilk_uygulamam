workflows:
  ios-unsigned-build:
    name: iOS Unsigned Build (AltStore için)
    max_build_duration: 60
    instance_type: mac_mini_m2
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: main
          include: true
          source: true
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
    scripts:
      - name: Flutter bağımlılıklarını kur
        script: |
          flutter pub get

      - name: iOS'u imzasız olarak derle
        script: |
          flutter build ios --release --no-codesign

      - name: İmzasız .ipa dosyası oluştur
        script: |
          mkdir -p build/ios/iphoneos/Payload
          cp -r build/ios/iphoneos/Runner.app build/ios/iphoneos/Payload/
          cd build/ios/iphoneos
          zip -r unsigned.ipa Payload
    artifacts:
      - build/ios/iphoneos/unsigned.ipa