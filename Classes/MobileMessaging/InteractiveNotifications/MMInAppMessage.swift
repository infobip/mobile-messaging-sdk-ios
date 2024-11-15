import Foundation

@objcMembers
public final class MMInAppMessage: MM_MTMessage {
    let clickUrl: URL?
    let url: URL
    let type: MMInAppMessageType
    let position: MMInAppMessagePosition?
    
    public override init?(payload: MMAPNSPayload,
                          deliveryMethod: MMMessageDeliveryMethod,
                          seenDate: Date?, deliveryReportDate: Date?,
                          seenStatus: MMSeenStatus,
                          isDeliveryReportSent: Bool) {
        guard
            let internalData = payload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload,
            let inAppDetails = internalData[Consts.InternalDataKeys.inAppDetails] as? MMStringKeyPayload,
            let urlRaw = inAppDetails[Consts.InAppDetailsKeys.url] as? String,
            let url = URL(string: urlRaw),
            let typeRaw = inAppDetails[Consts.InAppDetailsKeys.type] as? Int,
            let type = MMInAppMessageType(rawValue: typeRaw)
        else {
            return nil
        }
        
        let clickUrlRaw = inAppDetails[Consts.InAppDetailsKeys.clickUrl] as? String
        let clickUrl = clickUrlRaw.flatMap { URL(string: $0) }
        
        self.url = url
        self.type = type
        self.clickUrl = clickUrl
        
        if type == .banner {
            guard
                let positionRaw = inAppDetails[Consts.InAppDetailsKeys.position] as? Int,
                let position = MMInAppMessagePosition(rawValue: positionRaw)
            else {
                return nil
            }
            
            self.position = position
        } else {
            self.position = nil
        }
        
        super.init(payload: payload,
                   deliveryMethod: deliveryMethod,
                   seenDate: seenDate,
                   deliveryReportDate: deliveryReportDate,
                   seenStatus: seenStatus,
                   isDeliveryReportSent: isDeliveryReportSent)
    }
    
    convenience init?(from message: MM_MTMessage) {
            self.init(
                payload: message.originalPayload,
                deliveryMethod: message.deliveryMethod,
                seenDate: message.seenDate,
                deliveryReportDate: message.deliveryReportedDate,
                seenStatus: message.seenStatus,
                isDeliveryReportSent: message.isDeliveryReportSent
            )
        }
}

public enum MMInAppMessagePosition: Int {
    case top = 0, bottom
}

public enum MMInAppMessageType: Int {
    case banner = 0, popup, fullscreen
    
    static let bannerButtonIdx = "banner"
    static let primaryButtonIdx = "primary_button"

    var buttonIdx: String {
        switch self {
        case .banner:
            return MMInAppMessageType.bannerButtonIdx
        default:
            return MMInAppMessageType.primaryButtonIdx
        }
    }
}
