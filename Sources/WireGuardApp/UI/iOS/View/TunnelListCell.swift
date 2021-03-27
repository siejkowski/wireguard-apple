// SPDX-License-Identifier: MIT
// Copyright © 2018-2020 WireGuard LLC. All Rights Reserved.

import UIKit

class TunnelListCell: UITableViewCell {
    var tunnel: TunnelContainer? {
        didSet {
            // Bind to the tunnel's name
            nameLabel.text = tunnel?.name ?? ""
            nameObservationToken = tunnel?.observe(\.name) { [weak self] tunnel, _ in
                self?.nameLabel.text = tunnel.name
            }
            // Bind to the tunnel's status
            update(from: tunnel, animated: false)
            statusObservationToken = tunnel?.observe(\.status) { [weak self] tunnel, _ in
                self?.update(from: tunnel, animated: true)
            }
            effectiveActivateOnDemandToken = tunnel?.observe(\.effectiveActivateOnDemandEnabled) { [weak self] tunnel, _ in
                self?.update(from: tunnel, animated: true)
            }
        }
    }
    var onSwitchToggled: ((Bool) -> Void)?

    let nameLabel: UILabel = {
        let nameLabel = UILabel()
        nameLabel.font = UIFont.preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0
        return nameLabel
    }()

    let subTitleLabel: UILabel = {
        let subTitleLabel = UILabel()
        subTitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        if #available(iOS 13.0, *) {
            subTitleLabel.textColor = .secondaryLabel
        } else {
            subTitleLabel.textColor = .systemGray
        }
        subTitleLabel.adjustsFontForContentSizeCategory = true
        return subTitleLabel
    }()

    let busyIndicator: UIActivityIndicatorView = {
        let busyIndicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            busyIndicator = UIActivityIndicatorView(style: .medium)
        } else {
            busyIndicator = UIActivityIndicatorView(style: .gray)
        }
        busyIndicator.hidesWhenStopped = true
        return busyIndicator
    }()

    let statusSwitch = UISwitch()

    private var statusObservationToken: NSKeyValueObservation?
    private var nameObservationToken: NSKeyValueObservation?
    private var effectiveActivateOnDemandToken: NSKeyValueObservation?

    private var subTitleLabelBottomConstraint: NSLayoutConstraint?
    private var nameLabelBottomConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        accessoryType = .disclosureIndicator

        for subview in [statusSwitch, busyIndicator, nameLabel, subTitleLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subview)
        }

        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let nameLabelBottomConstraint =
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: nameLabel.bottomAnchor, multiplier: 1)
        nameLabelBottomConstraint.priority = .defaultLow
        self.nameLabelBottomConstraint = nameLabelBottomConstraint

        subTitleLabelBottomConstraint =
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: subTitleLabel.bottomAnchor, multiplier: 1)
        subTitleLabelBottomConstraint?.priority = .defaultLow

        NSLayoutConstraint.activate([
            statusSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusSwitch.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            statusSwitch.leadingAnchor.constraint(equalToSystemSpacingAfter: busyIndicator.trailingAnchor, multiplier: 1),

            nameLabel.topAnchor.constraint(equalToSystemSpacingBelow: contentView.layoutMarginsGuide.topAnchor, multiplier: 1),
            nameLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: contentView.layoutMarginsGuide.leadingAnchor, multiplier: 1),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusSwitch.leadingAnchor),
            nameLabelBottomConstraint,

            subTitleLabel.topAnchor.constraint(equalToSystemSpacingBelow: nameLabel.bottomAnchor, multiplier: 0.25),
            subTitleLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: contentView.layoutMarginsGuide.leadingAnchor, multiplier: 1),
            subTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusSwitch.leadingAnchor),

            busyIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            busyIndicator.leadingAnchor.constraint(equalToSystemSpacingAfter: nameLabel.trailingAnchor, multiplier: 1)
        ])

        statusSwitch.addTarget(self, action: #selector(switchToggled), for: .valueChanged)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        reset(animated: false)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        statusSwitch.isEnabled = !editing
    }

    @objc private func switchToggled() {
        onSwitchToggled?(statusSwitch.isOn)
    }

    private func setSubTitleText(_ string: String?) {
        if let string = string {
            subTitleLabel.text = string
            subTitleLabel.isHidden = false
            nameLabelBottomConstraint?.isActive = false
            subTitleLabelBottomConstraint?.isActive = true
        } else {
            subTitleLabel.text = nil
            subTitleLabel.isHidden = true
            subTitleLabelBottomConstraint?.isActive = false
            nameLabelBottomConstraint?.isActive = true
        }
    }

    private func update(from tunnel: TunnelContainer?, animated: Bool) {
        guard let tunnel = tunnel else {
            reset(animated: animated)
            return
        }

        let status = tunnel.status

        if tunnel.effectiveActivateOnDemandEnabled {
            setSubTitleText(tr("tunnelsListOnDemandActiveCellSubTitle"))
        } else {
            setSubTitleText(nil)
        }

        statusSwitch.setOn(!(status == .deactivating || status == .inactive) || (status == .inactive && tunnel.effectiveActivateOnDemandEnabled), animated: animated)
        statusSwitch.isUserInteractionEnabled = (status == .inactive || status == .active)

        if case .inactive = status, tunnel.effectiveActivateOnDemandEnabled {
            statusSwitch.tintColor = UIColor.systemOrange
            statusSwitch.onTintColor = UIColor.systemOrange
        } else {
            statusSwitch.tintColor = nil
            statusSwitch.onTintColor = nil
        }

        if status == .inactive || status == .active {
            busyIndicator.stopAnimating()
        } else {
            busyIndicator.startAnimating()
        }
    }

    private func reset(animated: Bool) {
        setSubTitleText(nil)
        statusSwitch.thumbTintColor = nil
        statusSwitch.setOn(false, animated: animated)
        statusSwitch.isUserInteractionEnabled = false
        busyIndicator.stopAnimating()
    }
}
