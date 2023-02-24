import Foundation

/// Contains all information necessary for displaying a new-style web-based in-app notification.
internal struct MMWebInAppMessage {
    let url: URL
    let type: InAppMessageType
    let position: InAppMessagePosition?
    
    /// Extracts in-app message information from message if it's possible.
    init?(extractedFrom message: MM_MTMessage) {
        guard
            let internalData = message.internalData,
            let inAppDetails = internalData[Consts.InternalDataKeys.inAppDetails] as? MMStringKeyPayload,
            let urlRaw = inAppDetails[Consts.InAppDetailsKeys.url] as? String,
            let url = URL(string: urlRaw),
            let typeRaw = inAppDetails[Consts.InAppDetailsKeys.type] as? Int,
            let type = InAppMessageType(rawValue: typeRaw)
        else {
            return nil
        }
        
        self.url = url
        self.type = type
        
        if type == .banner {
            guard
                let positionRaw = inAppDetails[Consts.InAppDetailsKeys.position] as? Int,
                let position = InAppMessagePosition(rawValue: positionRaw)
            else {
                return nil
            }
            
            self.position = position
        } else {
            self.position = nil
        }
    }
}
