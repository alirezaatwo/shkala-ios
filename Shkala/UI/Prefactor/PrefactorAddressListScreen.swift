import SwiftUI

// معادل ui/prefactor/PrefactorAddressListScreen.kt

struct PrefactorAddressListScreen: View {
    let uuid: String
    let onBack: () -> Void
    let onAddAddress: () -> Void
    let onEditAddress: (AddressDto) -> Void

    @Environment(\.shkColors) private var colors
    // آدرس‌ها (فهرست/افزودن/ویرایش/حذف) از همون CheckoutRepository مشترکه؛ انتخاب
    // حضوری/ارسال برای همین پیش‌فاکتور از PrefactorRepository
    private let addressRepository = CheckoutRepository()
    private let prefactorRepository = PrefactorRepository()

    @State private var addresses: [AddressDto] = []
    @State private var receptionCenters: [ReceptionCenterDto] = []
    @State private var selectedUserAddressId: Int? = nil
    @State private var selectedShopCenterId: String? = nil
    @State private var isLoading = true
    @State private var mutatingId: String? = nil

    private func refresh() async {
        if case .success(let list) = await addressRepository.getAddresses() { addresses = list }
        if case .success(let detail) = await prefactorRepository.getPrefactorDetail(uuid) {
            receptionCenters = detail.receptionCenters ?? []
            let selected = detail.selectedAddress
            selectedUserAddressId = selected.selectedUserAddressId()
            selectedShopCenterId = selected.selectedShopCenterId()
        }
        isLoading = false
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "دریافت حضوری / ارسال به آدرس", onBack: onBack)

            if isLoading {
                SiteLoading(message: "در حال دریافت آدرس‌ها...", icon: RemixIcons.MapPin2Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // کشیدن صفحه به پایین: آدرس‌ها و شعبه‌ها بی‌صدا از سرور تازه می‌شن
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if !receptionCenters.isEmpty {
                            SiteSectionTitle("تحویل حضوری از شعبه").padding(.top, 6).padding(.bottom, 2)
                            // اصلاحیه (پیشگیری از کرش «Key already used»): آیتم تکراری یکتا می‌شه
                            ForEach(receptionCenters.uniqueById()) { center in
                                PrefactorShopCenterRow(
                                    center: center,
                                    isSelected: center.id == selectedShopCenterId,
                                    isMutating: mutatingId == "shop-\(center.id)",
                                    onSelect: {
                                        mutatingId = "shop-\(center.id)"
                                        Task {
                                            switch await prefactorRepository.selectShopAddress(uuid, receptionCenterId: center.id) {
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

                        SiteSectionTitle("ارسال به آدرس")
                            .padding(.top, receptionCenters.isEmpty ? 6 : 10)
                            .padding(.bottom, 2)

                        if addresses.isEmpty {
                            SiteEmptyState(
                                icon: RemixIcons.MapPin2Line,
                                title: "هنوز آدرسی ثبت نکرده‌اید",
                                subtitle: nil,
                                actionLabel: "افزودن آدرس جدید",
                                actionIcon: RemixIcons.AddLine,
                                onAction: onAddAddress
                            )
                        }

                        ForEach(addresses.uniqueById()) { address in
                            PrefactorAddressRow(
                                address: address,
                                isSelected: address.id == selectedUserAddressId,
                                isMutating: mutatingId == "addr-\(address.id)",
                                onSelect: {
                                    mutatingId = "addr-\(address.id)"
                                    Task {
                                        switch await prefactorRepository.selectAddress(uuid, addressId: address.id) {
                                        case .success:
                                            mutatingId = nil
                                            onBack()
                                        case .error(let message):
                                            mutatingId = nil
                                            ShkToast.shared.show(message, long: true)
                                        }
                                    }
                                },
                                onEdit: { onEditAddress(address) },
                                onDelete: {
                                    Task {
                                        _ = await addressRepository.deleteAddress(address.id)
                                        await refresh()
                                    }
                                }
                            )
                        }

                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 16)
                }
                .sitePullRefresh { await refresh() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                SiteSecondaryButton(text: "افزودن آدرس جدید", onClick: onAddAddress, icon: RemixIcons.AddLine, fillWidth: true)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        Rectangle()
                            .fill(colors.surface)
                            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: -1)
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        // معادل LaunchedEffect: با برگشت از فرم آدرس، صفحه دوباره ساخته و فهرست تازه می‌شه
        .task { await refresh() }
    }
}

/** کارت انتخاب آدرس/شعبه (انتخاب‌شده: حاشیه‌ی قرمز و تیک) */
private struct SelectableLocationCard<Actions: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isMutating: Bool
    let onSelect: () -> Void
    let actions: Actions?

    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 0) {
            SiteIconBadge(icon: icon, tint: isSelected ? primary : colors.onSurfaceVariant)
            Spacer().frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).shkFont(13, .bold).foregroundColor(colors.onSurface).lineLimit(1).truncationMode(.tail)
                Spacer().frame(height: 2)
                Text(subtitle)
                    .shkFont(11, lineHeight: 19)
                    .foregroundColor(colors.onSurfaceVariant)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let actions {
                Spacer().frame(width: 6)
                actions
            }
            Spacer().frame(width: 6)
            ZStack {
                if isMutating {
                    MaterialSpinner(color: primary, lineWidth: 2, size: 20)
                } else {
                    RemixIcon(isSelected ? RemixIcons.CheckboxCircleFill : RemixIcons.CheckboxBlankCircleLine,
                              tint: isSelected ? primary : colors.onSurfaceVariant, size: 22)
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(shape.fill(colors.surface))
        .overlay(shape.strokeBorder(isSelected ? primary : Color.clear, lineWidth: 1.5))
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture(perform: onSelect)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct PrefactorAddressRow: View {
    let address: AddressDto
    let isSelected: Bool
    let isMutating: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SelectableLocationCard(
            icon: RemixIcons.MapPin2Line,
            title: address.fullName,
            subtitle: "\(address.state), \(address.city) - \(address.fullAddress)",
            isSelected: isSelected,
            isMutating: isMutating,
            onSelect: onSelect,
            actions: HStack(spacing: 6) {
                SiteIconButton(icon: RemixIcons.EditLine, contentDescription: "ویرایش", onClick: onEdit, size: 32, background: colors.surfaceVariant)
                SiteIconButton(icon: RemixIcons.DeleteBin6Line, contentDescription: "حذف", onClick: onDelete, size: 32,
                               tint: colors.error, background: colors.error.opacity(0.1))
            }
        )
    }
}

private struct PrefactorShopCenterRow: View {
    let center: ReceptionCenterDto
    let isSelected: Bool
    let isMutating: Bool
    let onSelect: () -> Void

    var body: some View {
        SelectableLocationCard<EmptyView>(
            icon: RemixIcons.Store2Line,
            title: "\(center.state ?? ""), \(center.city ?? "")",
            subtitle: center.fullAddress ?? "",
            isSelected: isSelected,
            isMutating: isMutating,
            onSelect: onSelect,
            actions: nil
        )
    }
}
