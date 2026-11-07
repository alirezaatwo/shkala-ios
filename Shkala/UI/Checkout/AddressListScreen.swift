import SwiftUI

// ===================================================================================
// معادل ui/checkout/AddressListScreen.kt
// بازطراحی: صفحه‌ی «آدرس‌ها و نحوه‌ی دریافت» و «روش ارسال» - کارت‌های قابل‌انتخاب با
// حاشیه‌ی قرمز و نشان تیک در حالت انتخاب، دکمه‌های کوچک ویرایش/حذف و کارت خط‌چینِ افزودن
// آدرس.
// ===================================================================================

private enum AddressScreenMode { LIST, METHODS }

struct AddressListScreen: View {
    let onBack: () -> Void
    let onAddAddress: () -> Void
    let onEditAddress: (AddressDto) -> Void

    @Environment(\.shkColors) private var colors
    @ObservedObject private var navigator = AppNavigator.shared
    private let repository = CheckoutRepository()

    @State private var screen: AddressScreenMode = .LIST
    @State private var addresses: [AddressDto] = []
    @State private var receptionCenters: [ReceptionCenterDto] = []
    @State private var selectedUserAddressId: Int? = nil
    @State private var selectedShopCenterId: String? = nil
    @State private var consignments: [ConsignmentEntry] = []
    @State private var isLoading = true
    @State private var mutatingId: String? = nil
    @State private var ownDepth: Int? = nil

    private func refresh() async {
        if case .success(let list) = await repository.getAddresses() { addresses = list }
        if case .success(let shipping) = await repository.getShipping() {
            receptionCenters = shipping.receptionCenters ?? []
            consignments = shipping.consignments ?? []
            let selected = shipping.selectedAddress
            selectedUserAddressId = selected.selectedUserAddressId()
            selectedShopCenterId = selected.selectedShopCenterId()
        }
        isLoading = false
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(
                title: screen == .LIST ? "آدرس‌ها و نحوه‌ی دریافت" : "روش ارسال",
                onBack: { if screen == .METHODS { screen = .LIST } else { onBack() } }
            )

            if isLoading {
                SiteLoading(message: "در حال دریافت آدرس‌ها...", icon: RemixIcons.MapPin2Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if screen == .LIST {
                listContent
            } else {
                methodsContent
            }
        }
        .background(colors.background)
        .task {
            if ownDepth == nil { ownDepth = navigator.stack.count }
            await refresh()
        }
        // معادل ترکیب دوباره‌ی صفحه بعد از برگشت از فرم آدرس (صفحه از اول ساخته و تازه می‌شه)
        .onChange(of: navigator.stack.count) { count in
            if count == ownDepth {
                screen = .LIST
                Task { await refresh() }
            }
        }
    }

    private func pullRefresh() async {
        if PullRefreshRateLimiter.tryAcquire() {
            await refresh()
        } else {
            ShkToast.shared.show(PULL_REFRESH_LIMIT_MESSAGE, long: true)
        }
    }

    // کشیدن صفحه به پایین: آدرس‌ها و شعبه‌ها بی‌صدا از سرور تازه می‌شن
    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if !receptionCenters.isEmpty {
                    SiteSectionTitle("تحویل حضوری از شعبه").padding(.top, 6)
                    // پیشگیری از شناسه‌ی تکراری: اگه سرور یک آیتم رو دوبار بفرسته، اینجا یکتا می‌شه
                    ForEach(distinct(receptionCenters, \.id), id: \.id) { center in
                        ShopCenterRow(
                            center: center,
                            isSelected: center.id == selectedShopCenterId,
                            isMutating: mutatingId == "shop-\(center.id)",
                            onSelect: {
                                mutatingId = "shop-\(center.id)"
                                Task {
                                    switch await repository.selectShopAddress(center.id) {
                                    case .success:
                                        mutatingId = nil
                                        onBack()
                                    case .error(let message):
                                        mutatingId = nil
                                        ShkToast.shared.show(message, long: true)
                                    }
                                }
                            }
                        )
                    }
                }

                SiteSectionTitle("ارسال به آدرس").padding(.top, receptionCenters.isEmpty ? 6 : 14)

                if addresses.isEmpty {
                    SiteEmptyState(icon: RemixIcons.MapPin2Line, title: "هنوز آدرسی ثبت نکرده‌اید", subtitle: nil)
                        .frame(maxWidth: .infinity)
                }

                ForEach(distinct(addresses, \.id), id: \.id) { address in
                    AddressRow(
                        address: address,
                        isSelected: address.id == selectedUserAddressId,
                        isMutating: mutatingId == "addr-\(address.id)",
                        onSelect: {
                            mutatingId = "addr-\(address.id)"
                            Task {
                                switch await repository.selectAddress(address.id) {
                                case .success:
                                    // بعد از انتخاب آدرس، حتماً باید روش ارسال هم مشخص بشه
                                    await refresh()
                                    mutatingId = nil
                                    screen = .METHODS
                                case .error(let message):
                                    mutatingId = nil
                                    ShkToast.shared.show(message, long: true)
                                }
                            }
                        },
                        onEdit: { onEditAddress(address) },
                        onDelete: {
                            Task {
                                _ = await repository.deleteAddress(address.id)
                                await refresh()
                            }
                        }
                    )
                }

                // کارت خط‌چین «افزودن آدرس جدید»
                AddAddressDashedCard(onClick: onAddAddress)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .refreshable { await pullRefresh() }
    }

    // انتخاب روش ارسال برای آدرسی که همین الان انتخاب شد
    @ViewBuilder
    private var methodsContent: some View {
        let allSelected = consignments.allSatisfy { $0.value.sendMethod != nil }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SiteSectionTitle("نحوه‌ی ارسال مرسوله").padding(.top, 6)
                ForEach(consignments) { entry in
                    let key = entry.key
                    let consignment = entry.value
                    ConsignmentShippingCard(
                        storeLabel: key == "main" ? "فروشگاه اصلی" : "فروشنده",
                        consignment: consignment,
                        onSelect: { wayUuid in
                            Task {
                                _ = await repository.selectShippingMethod(
                                    type: key == "main" ? "main" : "direct",
                                    consignmentUuid: consignment.uuid ?? key,
                                    sendMethodUuid: wayUuid
                                )
                                await refresh()
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .refreshable { await pullRefresh() }

        SitePrimaryButton(
            text: allSelected ? "تایید و بازگشت" : "ابتدا یک روش ارسال انتخاب کنید",
            onClick: onBack,
            icon: allSelected ? RemixIcons.CheckLine : nil,
            enabled: allSelected,
            fillWidth: true
        )
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            TopRoundedShape(radius: 20)
                .fill(colors.surface)
                .shadow(color: .black.opacity(0.14), radius: 9, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

/// معادل distinctBy کاتلین
func distinct<T, K: Hashable>(_ list: [T], _ key: KeyPath<T, K>) -> [T] {
    var seen = Set<K>()
    return list.filter { seen.insert($0[keyPath: key]).inserted }
}

/** نشانگر انتخاب: دایره‌ی خالی ← دایره‌ی قرمز با تیک (با انیمیشن) */
struct AddressSelectIndicator: View {
    let selected: Bool
    var isMutating: Bool = false
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        ZStack {
            if isMutating {
                MaterialSpinner(color: primary, lineWidth: 2, size: 20)
            } else {
                ZStack {
                    Circle().fill(selected ? primary : .clear)
                    Circle().strokeBorder(selected ? primary : colors.onSurfaceVariant.opacity(0.4), lineWidth: 1.5)
                    RemixIcon(RemixIcons.CheckLine, tint: .white, size: 15).scaleEffect(selected ? 1 : 0.001)
                }
                .frame(width: 22, height: 22)
            }
        }
        .frame(width: 24, height: 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}

private struct ConsignmentShippingCard: View {
    let storeLabel: String
    let consignment: ConsignmentShippingDto
    let onSelect: (String) -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let selectedUuid = consignment.sendMethod.selectedPostWayUuid()
        SiteCard {
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.Store2Line, size: 36, iconSize: 18, radius: 11)
                Spacer().frame(width: 10)
                Text(storeLabel).shkFont(14, .bold).foregroundColor(colors.onSurface).frame(maxWidth: .infinity, alignment: .leading)
                if selectedUuid != nil {
                    SiteStatusChip(text: "انتخاب شد", color: colors.primary, icon: RemixIcons.CheckLine)
                }
            }
            SiteDashedDivider().padding(.vertical, 12)

            let ways = consignment.postWays ?? []
            if ways.isEmpty {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.ErrorWarningLine, tint: colors.error, size: 16)
                    Spacer().frame(width: 6)
                    Text("روش ارسالی برای این مرسوله تعریف نشده").shkFont(12).foregroundColor(colors.error)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(ways.enumerated()), id: \.offset) { _, way in
                        ShippingWayRow(way: way, isSelected: way.uuid == selectedUuid, onClick: { onSelect(way.uuid) })
                    }
                }
            }
        }
    }
}

/** گزینه‌ی روش ارسال: کادر قابل‌انتخاب با آیکن، عنوان، هزینه و نشانگر انتخاب */
private struct ShippingWayRow: View {
    let way: PostWayDto
    let isSelected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 0) {
            SiteIconBadge(icon: RemixIcons.TruckLine, size: 36, iconSize: 18, tint: isSelected ? primary : colors.onSurfaceVariant, radius: 10)
            Spacer().frame(width: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(way.title ?? "روش ارسال")
                    .shkFont(13, isSelected ? .bold : .medium)
                    .foregroundColor(colors.onSurface)
                if let price = way.price, !price.isBlankShk {
                    Text("\(price.toPersianDigits()) تومان")
                        .shkFont(11)
                        .foregroundColor(isSelected ? primary : colors.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 8)
            AddressSelectIndicator(selected: isSelected)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(shape.fill(isSelected ? primary.opacity(0.06) : colors.surfaceVariant.opacity(0.6)))
        .overlay(shape.stroke(isSelected ? primary : .clear, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture(perform: onClick)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/** کارت آدرس کاربر: آیکن سنجاق نقشه، نام و آدرس، ویرایش/حذف، حالت انتخاب با حاشیه‌ی قرمز */
private struct AddressRow: View {
    let address: AddressDto
    let isSelected: Bool
    let isMutating: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        SiteCard(onClick: onSelect, borderColor: isSelected ? primary : .clear) {
            HStack(alignment: .top, spacing: 0) {
                SiteIconBadge(icon: RemixIcons.MapPin2Line, size: 42, iconSize: 21, filled: isSelected)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(address.fullName).shkFont(14, .bold).foregroundColor(colors.onSurface)
                    Spacer().frame(height: 3)
                    Text("\(address.state), \(address.city) - \(address.fullAddress)")
                        .shkFont(12, lineHeight: 21)
                        .foregroundColor(colors.onSurfaceVariant)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 8)
                AddressSelectIndicator(selected: isSelected, isMutating: isMutating)
            }
            SiteDashedDivider().padding(.top, 12).padding(.bottom, 10)
            HStack(spacing: 0) {
                if isSelected {
                    SiteStatusChip(text: "آدرس انتخاب‌شده", color: primary, icon: RemixIcons.CheckboxCircleLine)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                SmallActionButton(icon: RemixIcons.PencilLine, contentDescription: "ویرایش", tint: colors.onSurfaceVariant, onClick: onEdit)
                Spacer().frame(width: 8)
                SmallActionButton(icon: RemixIcons.DeleteBin6Line, contentDescription: "حذف", tint: colors.error, onClick: onDelete)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/** دکمه‌ی آیکنیِ کوچک (ویرایش/حذف) */
private struct SmallActionButton: View {
    let icon: String
    let contentDescription: String
    let tint: Color
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.1))
                RemixIcon(icon, contentDescription: contentDescription, tint: tint, size: 17)
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(SitePressStyle())
    }
}

/** کارت خط‌چین افزودن آدرس جدید */
private struct AddAddressDashedCard: View {
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: onClick) {
            HStack(spacing: 0) {
                ZStack {
                    Circle().fill(primary)
                    RemixIcon(RemixIcons.AddLine, tint: .white, size: 18)
                }
                .frame(width: 30, height: 30)
                Spacer().frame(width: 10)
                Text("افزودن آدرس جدید").shkFont(14, .bold).foregroundColor(primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .background(shape.fill(primary.opacity(0.04)))
            // خط‌چین ۱۲/۹ پیکسل اندروید (~۴/۳ نقطه)
            .overlay(shape.stroke(primary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            .contentShape(shape)
        }
        .buttonStyle(SitePressStyle())
    }
}

/** کارت شعبه‌ی تحویل حضوری */
private struct ShopCenterRow: View {
    let center: ReceptionCenterDto
    let isSelected: Bool
    let isMutating: Bool
    let onSelect: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard(onClick: onSelect, borderColor: isSelected ? colors.primary : .clear) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.Store2Line, size: 42, iconSize: 21, filled: isSelected)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(center.state ?? ""), \(center.city ?? "")").shkFont(14, .bold).foregroundColor(colors.onSurface)
                    Text(center.fullAddress ?? "")
                        .shkFont(12, lineHeight: 21)
                        .foregroundColor(colors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 8)
                AddressSelectIndicator(selected: isSelected, isMutating: isMutating)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
