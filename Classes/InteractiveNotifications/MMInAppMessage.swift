import Foundation

@objcMembers
public final class MMInAppMessage: MM_MTMessage {
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
        
        self.url = url
        self.type = type
        
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
}

public enum MMInAppMessagePosition: Int {
    case top = 0, bottom
}

public enum MMInAppMessageType: Int {
    case banner = 0, popup, fullscreen
}
