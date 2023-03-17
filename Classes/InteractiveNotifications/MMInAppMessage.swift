import Foundation

@objcMembers
public final class MMInAppMessage: MM_MTMessage {
    private var _url: URL!
    private var _type: MMInAppMessageType!
    private var _position: MMInAppMessagePosition?
    
    public var url: URL { get { _url } }
    public var type: MMInAppMessageType { get { _type } }
    public var position: MMInAppMessagePosition? { get { _position } }
    
    public override init?(payload: MMAPNSPayload,
                          deliveryMethod: MMMessageDeliveryMethod,
                          seenDate: Date?, deliveryReportDate: Date?,
                          seenStatus: MMSeenStatus,
                          isDeliveryReportSent: Bool) {
        super.init(payload: payload,
                   deliveryMethod: deliveryMethod,
                   seenDate: seenDate,
                   deliveryReportDate: deliveryReportDate,
                   seenStatus: seenStatus,
                   isDeliveryReportSent: isDeliveryReportSent)
        
        guard
            let internalData,
            let inAppDetails = internalData[Consts.InternalDataKeys.inAppDetails] as? MMStringKeyPayload,
            let urlRaw = inAppDetails[Consts.InAppDetailsKeys.url] as? String,
            let url = URL(string: urlRaw),
            let typeRaw = inAppDetails[Consts.InAppDetailsKeys.type] as? Int,
            let type = MMInAppMessageType(rawValue: typeRaw)
        else {
            return nil
        }
        
        self._url = url
        self._type = type
        
        if type == .banner {
            guard
                let positionRaw = inAppDetails[Consts.InAppDetailsKeys.position] as? Int,
                let position = MMInAppMessagePosition(rawValue: positionRaw)
            else {
                return nil
            }
            
            self._position = position
        } else {
            self._position = nil
        }
    }
}
