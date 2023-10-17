//
//  ExpandedSheetView.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 20/09/2023.
//

import UIKit
#if WEBRTCUI_ENABLED
class SelfSizingTableView: UITableView {
    var maxSize: CGFloat = UIScreen.main.bounds.height * 0.5
    
    override var contentSize: CGSize {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let height = min(maxSize, contentSize.height)
        return CGSize(width: contentSize.width, height: height)
    }
}

class CallTableOptionsView: UIView, UITableViewDelegate, UITableViewDataSource {
    struct LayoutConstants {
        static let horizontalPadding: CGFloat = 51
        static let dividerTopPadding: CGFloat = 13
        static let dividerHeight: CGFloat = 1
        static let tableViewTopPadding: CGFloat = 7
        static let cellHeight: CGFloat = 38
    }
    
    private let reusableIdentifier = "CallOptionViewCellReusableIdentifier"
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: frame.width, height: tableView.frame.height + divider.frame.height)
    }
    
    lazy var tableView: SelfSizingTableView = {
        let tableView = SelfSizingTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(CallOptionViewCell.self, forCellReuseIdentifier: reusableIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.bounces = false
        tableView.separatorColor = .clear
        tableView.backgroundColor = MMWebRTCSettings.sharedInstance.sheetDragIndicatorColor
        return tableView
    }()
    
    lazy var divider: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = MMWebRTCSettings.sharedInstance.sheetDividerColor
        return view
    }()
    
    private var content: [HiddenCallButtonContent] = []
    var contentDidChange: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(divider)
        
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LayoutConstants.horizontalPadding),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LayoutConstants.horizontalPadding),
            divider.topAnchor.constraint(equalTo: topAnchor, constant: LayoutConstants.dividerTopPadding),
            divider.heightAnchor.constraint(equalToConstant: LayoutConstants.dividerHeight)
        ])
        
        addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LayoutConstants.horizontalPadding),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LayoutConstants.horizontalPadding),
            tableView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: LayoutConstants.tableViewTopPadding),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentDidChange?()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func addCell(with content: HiddenCallButtonContent...) {
        self.content.append(contentsOf: content)
        self.tableView.reloadData()
    }
    
    func addCell(with content: [HiddenCallButtonContent]) {
        self.content.append(contentsOf: content)
        self.tableView.reloadData()
    }
    
    func removeCell(with content: HiddenCallButtonContent) {
        if let index = self.content.firstIndex(where: { $0 == content }) {
            self.content.remove(at: index)
            self.tableView.reloadData()
        }
    }
    
    func setCell(with content: [HiddenCallButtonContent]) {
        self.content.removeAll()
        addCell(with: content)
    }
    // MARK: - TableView Delegate & Data source
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: reusableIdentifier) as? CallOptionViewCell else {
            return UITableViewCell()
        }
        let content = content[indexPath.row]
        cell.set(content: content)
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? CallOptionViewCell else { return }
        let item = content[indexPath.row]
        item.action(cell.imageButton)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return LayoutConstants.cellHeight
    }
}

class CallOptionViewCell: UITableViewCell {
    
    private var content: HiddenCallButtonContent?
    
    struct LayoutConstants {
        static let imageSize: CGFloat = 20
        static let textHorizontalPadding: CGFloat = 20
    }
    
    lazy var imageButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentMode = .scaleAspectFill
        return button
    }()
    
    lazy var text: UILabel = {
        let label = UILabel()
        label.textColor = MMWebRTCSettings.sharedInstance.rowActionLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        addSubview(imageButton)
        addSubview(text)
        
        NSLayoutConstraint.activate([
            imageButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageButton.widthAnchor.constraint(equalToConstant: LayoutConstants.imageSize),
            imageButton.heightAnchor.constraint(equalToConstant: LayoutConstants.imageSize)
        ])
        
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: imageButton.trailingAnchor, constant: LayoutConstants.textHorizontalPadding),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: LayoutConstants.textHorizontalPadding),
            text.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        self.backgroundColor = MMWebRTCSettings.sharedInstance.sheetBackgroundColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(content: HiddenCallButtonContent) {
        self.content = content
        self.imageButton.setImage(content.icon, for: .normal)
        self.imageButton.setImage(content.iconSelected, for: .selected)
        self.text.text = content.text
        content.button = imageButton
    }
}
#endif
