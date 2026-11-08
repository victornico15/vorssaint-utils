// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct CtrlShortcutsStrings {
    let title: String
    let hubDescription: String
    let caption: String
    let excludedApps: String
    let excludedCaption: String
    let activeNow: String
}

extension FeatureStrings {
    static func ctrlShortcuts(_ language: AppLanguage) -> CtrlShortcutsStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension CtrlShortcutsStrings {
    static let enUS = CtrlShortcutsStrings(
        title: "Ctrl shortcuts like Windows",
        hubDescription: "Use Ctrl+A, C, V, X and Z instead of Command",
        caption: "Press Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X and Ctrl+Z as Command shortcuts (select all, copy, paste, cut, undo). Command shortcuts keep working. Needs Accessibility.",
        excludedApps: "Excluded apps",
        excludedCaption: "Bundle IDs separated by commas. Terminals start excluded because Ctrl+C and Ctrl+Z mean something there.",
        activeNow: "Active now"
    )

    static let ptBR = CtrlShortcutsStrings(
        title: "Atalhos Ctrl como no Windows",
        hubDescription: "Use Ctrl+A, C, V, X e Z em vez de Command",
        caption: "Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X e Ctrl+Z funcionam como atalhos Command (selecionar tudo, copiar, colar, recortar, desfazer). Os atalhos Command continuam funcionando. Requer Acessibilidade.",
        excludedApps: "Apps excluídos",
        excludedCaption: "IDs de pacote separados por vírgula. Terminais começam excluídos porque Ctrl+C e Ctrl+Z têm outro significado neles.",
        activeNow: "Ativo agora"
    )

    static let tr = CtrlShortcutsStrings(
        title: "Windows gibi Ctrl kısayolları",
        hubDescription: "Command yerine Ctrl+A, C, V, X ve Z kullanın",
        caption: "Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X ve Ctrl+Z Command kısayolu olarak çalışır (tümünü seç, kopyala, yapıştır, kes, geri al). Command kısayolları da çalışmaya devam eder. Erişilebilirlik gerekir.",
        excludedApps: "Hariç tutulan uygulamalar",
        excludedCaption: "Paket kimlikleri virgülle ayrılır. Terminallerde Ctrl+C ve Ctrl+Z başka anlama geldiği için varsayılan olarak hariçtir.",
        activeNow: "Şimdi etkin"
    )

    static let ru = CtrlShortcutsStrings(
        title: "Сочетания Ctrl как в Windows",
        hubDescription: "Ctrl+A, C, V, X и Z вместо Command",
        caption: "Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X и Ctrl+Z работают как сочетания Command (выделить всё, копировать, вставить, вырезать, отменить). Сочетания Command продолжают работать. Нужен доступ Универсального доступа.",
        excludedApps: "Исключённые приложения",
        excludedCaption: "Идентификаторы пакетов через запятую. Терминалы исключены по умолчанию, так как в них Ctrl+C и Ctrl+Z имеют другой смысл.",
        activeNow: "Сейчас активно"
    )

    static let es = CtrlShortcutsStrings(
        title: "Atajos Ctrl como en Windows",
        hubDescription: "Usa Ctrl+A, C, V, X y Z en lugar de Command",
        caption: "Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X y Ctrl+Z funcionan como atajos de Command (seleccionar todo, copiar, pegar, cortar, deshacer). Los atajos de Command siguen funcionando. Requiere Accesibilidad.",
        excludedApps: "Apps excluidas",
        excludedCaption: "IDs de paquete separados por comas. Los terminales empiezan excluidos porque Ctrl+C y Ctrl+Z significan otra cosa allí.",
        activeNow: "Activo ahora"
    )

    static let sk = CtrlShortcutsStrings(
        title: "Skratky Ctrl ako vo Windows",
        hubDescription: "Ctrl+A, C, V, X a Z namiesto Command",
        caption: "Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X a Ctrl+Z fungujú ako skratky Command (vybrať všetko, kopírovať, vložiť, vystrihnúť, späť). Skratky Command fungujú ďalej. Vyžaduje Prístupnosť.",
        excludedApps: "Vylúčené aplikácie",
        excludedCaption: "ID balíkov oddelené čiarkami. Terminály sú predvolene vylúčené, lebo Ctrl+C a Ctrl+Z tam majú iný význam.",
        activeNow: "Aktívne"
    )

    static let de = CtrlShortcutsStrings(
        title: "Strg-Kurzbefehle wie unter Windows",
        hubDescription: "Strg+A, C, V, X und Z statt Command",
        caption: "Strg+A, Strg+C, Strg+V, Strg+X und Strg+Z funktionieren als Command-Kurzbefehle (alles auswählen, kopieren, einsetzen, ausschneiden, widerrufen). Command-Kurzbefehle funktionieren weiter. Erfordert Bedienungshilfen.",
        excludedApps: "Ausgeschlossene Apps",
        excludedCaption: "Bundle-IDs durch Kommas getrennt. Terminals sind vorab ausgeschlossen, da Strg+C und Strg+Z dort etwas anderes bedeuten.",
        activeNow: "Jetzt aktiv"
    )

    static let fr = CtrlShortcutsStrings(
        title: "Raccourcis Ctrl comme sous Windows",
        hubDescription: "Ctrl+A, C, V, X et Z au lieu de Commande",
        caption: "Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X et Ctrl+Z fonctionnent comme des raccourcis Commande (tout sélectionner, copier, coller, couper, annuler). Les raccourcis Commande continuent de fonctionner. Nécessite l’accessibilité.",
        excludedApps: "Apps exclues",
        excludedCaption: "Identifiants de bundle séparés par des virgules. Les terminaux sont exclus par défaut car Ctrl+C et Ctrl+Z y ont un autre sens.",
        activeNow: "Actif maintenant"
    )

    static let it = CtrlShortcutsStrings(
        title: "Scorciatoie Ctrl come su Windows",
        hubDescription: "Usa Ctrl+A, C, V, X e Z al posto di Comando",
        caption: "Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X e Ctrl+Z funzionano come scorciatoie Comando (seleziona tutto, copia, incolla, taglia, annulla). Le scorciatoie Comando continuano a funzionare. Richiede Accessibilità.",
        excludedApps: "App escluse",
        excludedCaption: "ID bundle separati da virgole. I terminali sono esclusi per impostazione predefinita perché Ctrl+C e Ctrl+Z vi hanno un altro significato.",
        activeNow: "Attivo ora"
    )

    static let ja = CtrlShortcutsStrings(
        title: "WindowsのようなCtrlショートカット",
        hubDescription: "CommandではなくCtrl+A、C、V、X、Zを使用",
        caption: "Ctrl+A、Ctrl+C、Ctrl+V、Ctrl+X、Ctrl+ZをCommandショートカット(すべて選択、コピー、ペースト、カット、取り消し)として動作させます。Commandショートカットもそのまま使えます。アクセシビリティが必要です。",
        excludedApps: "除外するApp",
        excludedCaption: "バンドルIDをカンマ区切りで入力。ターミナルではCtrl+CとCtrl+Zの意味が異なるため、初期状態で除外されています。",
        activeNow: "現在有効"
    )

    static let ko = CtrlShortcutsStrings(
        title: "Windows처럼 Ctrl 단축키",
        hubDescription: "Command 대신 Ctrl+A, C, V, X, Z 사용",
        caption: "Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+Z가 Command 단축키(전체 선택, 복사, 붙여넣기, 오려두기, 실행 취소)로 동작합니다. Command 단축키도 계속 작동합니다. 손쉬운 사용 권한이 필요합니다.",
        excludedApps: "제외할 앱",
        excludedCaption: "번들 ID를 쉼표로 구분합니다. 터미널에서는 Ctrl+C와 Ctrl+Z의 의미가 달라 기본적으로 제외됩니다.",
        activeNow: "현재 활성"
    )

    static let zhHans = CtrlShortcutsStrings(
        title: "像 Windows 一样的 Ctrl 快捷键",
        hubDescription: "用 Ctrl+A、C、V、X、Z 代替 Command",
        caption: "Ctrl+A、Ctrl+C、Ctrl+V、Ctrl+X、Ctrl+Z 将作为 Command 快捷键使用(全选、拷贝、粘贴、剪切、撤销)。Command 快捷键仍然有效。需要辅助功能权限。",
        excludedApps: "排除的 App",
        excludedCaption: "用逗号分隔 Bundle ID。终端中 Ctrl+C 和 Ctrl+Z 另有含义,默认已排除。",
        activeNow: "当前已启用"
    )

    static let zhTW = CtrlShortcutsStrings(
        title: "像 Windows 一樣的 Ctrl 快速鍵",
        hubDescription: "用 Ctrl+A、C、V、X、Z 取代 Command",
        caption: "Ctrl+A、Ctrl+C、Ctrl+V、Ctrl+X、Ctrl+Z 會作為 Command 快速鍵使用(全選、拷貝、貼上、剪下、還原)。Command 快速鍵仍可使用。需要輔助使用權限。",
        excludedApps: "排除的 App",
        excludedCaption: "以逗號分隔 Bundle ID。終端機中 Ctrl+C 和 Ctrl+Z 另有用途,預設已排除。",
        activeNow: "目前已啟用"
    )

    static let zhHK = CtrlShortcutsStrings(
        title: "像 Windows 一樣的 Ctrl 快速鍵",
        hubDescription: "用 Ctrl+A、C、V、X、Z 取代 Command",
        caption: "Ctrl+A、Ctrl+C、Ctrl+V、Ctrl+X、Ctrl+Z 會作為 Command 快速鍵使用(全選、拷貝、貼上、剪下、還原)。Command 快速鍵仍可使用。需要輔助使用權限。",
        excludedApps: "排除的 App",
        excludedCaption: "以逗號分隔 Bundle ID。終端機中 Ctrl+C 和 Ctrl+Z 另有用途,預設已排除。",
        activeNow: "目前已啟用"
    )

    static let uk = CtrlShortcutsStrings(
        title: "Ctrl-скорочення як у Windows",
        hubDescription: "Ctrl+A, C, V, X і Z замість Command",
        caption: "Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X і Ctrl+Z працюють як скорочення Command (вибрати все, копіювати, вставити, вирізати, скасувати). Скорочення Command також працюють. Потрібен доступ Універсального доступу.",
        excludedApps: "Виключені застосунки",
        excludedCaption: "Ідентифікатори пакетів через кому. Термінали виключені за замовчуванням, бо в них Ctrl+C і Ctrl+Z мають інше значення.",
        activeNow: "Зараз активно"
    )
}
