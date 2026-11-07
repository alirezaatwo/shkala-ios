import SwiftUI

// معادل ui/tools/ToolsScreen.kt

/** کلید ابزارهایی که اپ صفحه‌ی نیتیو دارن */
let HDD_CALCULATOR_KEY = "hdd_calculator"

/**
 * صفحه‌ی «ابزارهای کاربردی» (منوی همبرگری): فهرست ابزارهای فعال از پنل. ابزارهای شناخته‌شده
 * (HDD_CALCULATOR_KEY) نیتیو باز می‌شن و ابزار جدیدی که اپ هنوز نمی‌شناسه، با لینکش در صفحه‌ی وب داخلی.
 */
struct ToolsScreen: View {
    let onBack: () -> Void
    let onOpenTool: (ToolItemDto) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = ToolsRepository()
    @State private var data: ToolsResponse? = nil
    @State private var error: String? = nil
    @State private var reloadKey = 0

    var body: some View {
        let current = data
        VStack(spacing: 0) {
            SitePageTopBar(title: current?.title.flatMap { $0.isBlankShk ? nil : $0 } ?? TOOLS_TITLE, onBack: onBack)
            if current == nil && error == nil {
                SiteLoading(size: 56)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let current {
                let tools = (current.tools ?? []).filter { !($0.key ?? "").isBlankShk && !($0.title ?? "").isBlankShk }
                ScrollView {
                    LazyVStack(spacing: 12) {
                        SiteHeroCard(
                            icon: RemixIcons.ToolsLine,
                            title: current.title.flatMap { $0.isBlankShk ? nil : $0 } ?? TOOLS_TITLE,
                            subtitle: current.intro
                        )
                        if tools.isEmpty {
                            SiteEmptyState(icon: RemixIcons.ToolsLine, title: "در حال حاضر ابزاری فعال نیست", subtitle: nil)
                        }
                        ForEach(Array(tools.enumerated()), id: \.offset) { _, tool in
                            ToolRow(tool: tool, onClick: { onOpenTool(tool) })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            } else {
                VStack {
                    SiteEmptyState(
                        icon: RemixIcons.WifiOffLine,
                        title: error ?? "دریافت اطلاعات با خطا مواجه شد.",
                        subtitle: "اتصال اینترنت را بررسی کنید.",
                        actionLabel: "تلاش دوباره",
                        actionIcon: RemixIcons.RefreshLine,
                        onAction: { reloadKey += 1 }
                    )
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task(id: reloadKey) {
            error = nil
            switch await repository.getTools() {
            case .success(let d): data = d
            case .error(let message): error = message
            }
        }
    }
}

private struct ToolRow: View {
    let tool: ToolItemDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard(onClick: onClick, contentPadding: .all(14)) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: toolIconOf(tool), size: 50, iconSize: 25, tint: toolColorOf(tool, colors), radius: 15)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(tool.title ?? "").shkFont(14, .bold).foregroundColor(colors.onSurface)
                    if let summary = tool.summary, !summary.isBlankShk {
                        Text(summary)
                            .shkFont(12, lineHeight: 20)
                            .foregroundColor(colors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 8)
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
            }
        }
    }
}

/** آیکن هر ابزار در اپ (کلید ناشناخته = آیکن عمومی ابزار) */
func toolIcon(_ key: String?) -> String {
    switch key {
    case HDD_CALCULATOR_KEY: return RemixIcons.HardDrive2Line
    default: return RemixIcons.ToolsLine
    }
}
