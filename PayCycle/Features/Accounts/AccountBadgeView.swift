import SwiftUI

struct AccountBadgeView: View {
    let account: AnyAccount

    private var logoSize: CGSize {
        guard let logoName = account.institutionLogoAssetName else {
            return CGSize(width: 58, height: 18)
        }

        return account.logoSize(for: logoName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                if let logoName = account.institutionLogoAssetName {
                    logoImage(named: logoName)
                } else {
                    Text(account.monogram)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                }

                Spacer()
            }

            Spacer(minLength: 0)

            ZStack(alignment: .bottomLeading) {
                Text(account.badgeLabel)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, account.mask != nil ? 42 : 0)

                if let mask = account.mask {
                    Text(mask)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .frame(width: 150, height: 92, alignment: .topLeading)
        .background(
            AccountCardBackground(account: account)
        )
    }

    @ViewBuilder
    private func logoImage(named logoName: String) -> some View {
        if logoName == "InstitutionFamilyTrustLogo" {
            baseLogoImage(named: logoName)
                .clipShape(Circle())
        } else {
            baseLogoImage(named: logoName)
        }
    }

    private func baseLogoImage(named logoName: String) -> some View {
        Image(logoName)
            .renderingMode(logoName == "InstitutionAppleLogo" && account.usesAppleCardRainbowBackground ? .template : .original)
            .resizable()
            .scaledToFit()
            .frame(width: logoSize.width, height: logoSize.height, alignment: .topLeading)
            .foregroundStyle(.white)
            .accessibilityHidden(true)
    }
}

private struct AccountCardBackground: View {
    let account: AnyAccount

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: account.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                if account.usesAppleCardRainbowBackground {
                    AppleCardRainbowBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
    }
}

private struct AppleCardRainbowBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .rgb(255, 241, 228),
                    .rgb(255, 157, 51),
                    .rgb(255, 207, 24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    .rgb(154, 82, 244).opacity(0.98),
                    .rgb(177, 119, 242).opacity(0)
                ],
                center: UnitPoint(x: 0.08, y: 0.98),
                startRadius: 0,
                endRadius: 92
            )

            RadialGradient(
                colors: [
                    .rgb(67, 174, 126).opacity(0.86),
                    .rgb(100, 185, 150).opacity(0)
                ],
                center: UnitPoint(x: 0.47, y: 0.85),
                startRadius: 0,
                endRadius: 74
            )

            RadialGradient(
                colors: [
                    .rgb(231, 91, 170).opacity(0.72),
                    .rgb(238, 141, 185).opacity(0)
                ],
                center: UnitPoint(x: 0.18, y: 0.37),
                startRadius: 0,
                endRadius: 76
            )
        }
    }
}

private extension AnyAccount {
    var usesAppleCardRainbowBackground: Bool {
        institutionLogoAssetName == "InstitutionAppleLogo" &&
            !nickname.localizedCaseInsensitiveContains("savings")
    }

    func logoSize(for logoName: String) -> CGSize {
        switch logoName {
        case "InstitutionAppleLogo":
            return CGSize(width: 18, height: 20)
        case "InstitutionBankOfAmericaLogo":
            return CGSize(width: 110, height: 36)
        case "InstitutionCapitalOneLogo":
            return CGSize(width: 78, height: 24)
        case "InstitutionCitiLogo":
            return CGSize(width: 48, height: 20)
        case "InstitutionChaseLogo":
            return CGSize(width: 72, height: 18)
        case "InstitutionVenmoLogo":
            return CGSize(width: 42, height: 20)
        case "InstitutionFamilyTrustLogo":
            return CGSize(width: 30, height: 30)
        case "InstitutionAllegacyLogo":
            return CGSize(width: 78, height: 32)
        case "InstitutionDominionEnergyLogo":
            return CGSize(width: 84, height: 30)
        case "InstitutionRocketMortgageLogo":
            return CGSize(width: 86, height: 24)
        case "InstitutionInspiraLogo":
            return CGSize(width: 80, height: 24)
        default:
            return CGSize(width: 58, height: 18)
        }
    }
}

private extension Color {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }
}
