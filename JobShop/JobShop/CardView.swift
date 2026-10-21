//
//  CardView.swift
//  JobShop
//
//  Theme, the JobCard model, shared UI helpers, the match ring, and the swipe card.
//
import UIKit

// MARK: - Theme

enum Theme {
    static let green = UIColor(red: 0.18, green: 0.45, blue: 0.10, alpha: 1)
    static let chipGreen = UIColor(red: 0.74, green: 0.93, blue: 0.62, alpha: 1)
    static let background = UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1)
    static let fieldGray = UIColor(red: 0.93, green: 0.93, blue: 0.94, alpha: 1)
    static let heartRed = UIColor(red: 0.93, green: 0.22, blue: 0.28, alpha: 1)
    static let ringRed = UIColor(red: 0.74, green: 0.15, blue: 0.10, alpha: 1)
    static let ringGreen = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)
    static let linkBlue = UIColor(red: 0.10, green: 0.45, blue: 0.95, alpha: 1)

    static func logoColor(for company: String) -> UIColor {
        switch company.lowercased() {
        case "google": return UIColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1)
        case "aws", "amazon": return UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1)
        case "visa": return UIColor(red: 0.10, green: 0.20, blue: 0.55, alpha: 1)
        case "roblox": return UIColor(red: 0.20, green: 0.40, blue: 0.95, alpha: 1)
        case "netflix": return UIColor(red: 0.85, green: 0.07, blue: 0.13, alpha: 1)
        case "spotify": return UIColor(red: 0.11, green: 0.73, blue: 0.33, alpha: 1)
        case "jane street", "apple": return .black
        case "meta": return UIColor(red: 0.0, green: 0.40, blue: 0.95, alpha: 1)
        default: return .darkGray
        }
    }
}

// MARK: - Model

enum ApplicationStatus: String, CaseIterable {
    case notApplied = "Not Applied"
    case applied = "Applied"
    case interviewed = "Interviewed"
    case offer = "Offer"

    var color: UIColor {
        switch self {
        case .notApplied: return UIColor(white: 0.85, alpha: 1)
        case .applied: return UIColor(red: 0.96, green: 0.80, blue: 0.55, alpha: 1)
        case .interviewed: return UIColor(red: 0.85, green: 0.95, blue: 0.60, alpha: 1)
        case .offer: return UIColor(red: 0.35, green: 0.85, blue: 0.40, alpha: 1)
        }
    }
}

struct JobCard {
    let id = UUID()
    let company: String
    let title: String
    let location: String
    let description: String
    let matchPercent: Int
    let keywords: [String]
    let extraKeywords: Int
    let salary: String
    var dateMatched: String = "September 15th, 2026"
    var dateApplied: String = "September 15th, 2026"
    var status: ApplicationStatus = .notApplied
    var applyURL: URL? = nil
}

// MARK: - Shared UI helpers

func makeLabel(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular,
               color: UIColor = .black, lines: Int = 0) -> UILabel {
    let l = UILabel()
    l.text = text
    l.font = .systemFont(ofSize: size, weight: weight)
    l.textColor = color
    l.numberOfLines = lines
    return l
}

func makeChip(_ text: String, fontSize: CGFloat = 9) -> UIView {
    let l = makeLabel(text, size: fontSize, lines: 1)
    l.translatesAutoresizingMaskIntoConstraints = false
    let wrapper = UIView()
    wrapper.layer.cornerRadius = fontSize + 3
    wrapper.layer.borderWidth = 0.8
    wrapper.layer.borderColor = UIColor.black.cgColor
    wrapper.addSubview(l)
    NSLayoutConstraint.activate([
        l.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 3),
        l.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -3),
        l.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 8),
        l.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -8)
    ])
    return wrapper
}

/// Uses an image asset named after the company (e.g. "google", "jane_street") if you add one
/// to Assets.xcassets; otherwise falls back to a colored first letter.
enum CompanyLogo {
    static func make(for company: String, size: CGFloat) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: size).isActive = true
        container.heightAnchor.constraint(equalToConstant: size).isActive = true

        let content: UIView
        let assetName = company.lowercased().replacingOccurrences(of: " ", with: "_")
        if let image = UIImage(named: assetName) {
            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFit
            content = iv
        } else {
            let l = UILabel()
            l.text = String(company.prefix(1)).uppercased()
            l.font = .systemFont(ofSize: size * 0.85, weight: .bold)
            l.textColor = Theme.logoColor(for: company)
            l.textAlignment = .center
            l.adjustsFontSizeToFitWidth = true
            content = l
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }
}

// MARK: - Circular match ring

class MatchRingView: UIView {
    private let track = CAShapeLayer()
    private let progress = CAShapeLayer()
    private let label = UILabel()
    private let lineWidth: CGFloat

    init(percent: Int, lineWidth: CGFloat = 9, fontSize: CGFloat = 30) {
        self.lineWidth = lineWidth
        super.init(frame: .zero)

        [track, progress].forEach {
            $0.fillColor = UIColor.clear.cgColor
            $0.lineWidth = lineWidth
            $0.lineCap = .round
            layer.addSublayer($0)
        }
        track.strokeColor = Theme.ringRed.cgColor
        progress.strokeColor = Theme.ringGreen.cgColor
        progress.strokeEnd = CGFloat(percent) / 100

        label.text = "\(percent)%"
        label.font = .systemFont(ofSize: fontSize, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2 - 2
        let path = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                                radius: radius,
                                startAngle: -.pi / 2,
                                endAngle: 1.5 * .pi,
                                clockwise: true)
        track.path = path.cgPath
        progress.path = path.cgPath
    }
}

// MARK: - Swipe card

class CardView: UIView {
    let card: JobCard
    var onHeartTapped: (() -> Void)?
    var onTapped: (() -> Void)?
    private let heartButton = UIButton(type: .system)

    init(card: JobCard) {
        self.card = card
        super.init(frame: .zero)
        backgroundColor = .white
        layer.cornerRadius = 28
        layer.borderWidth = 1
        layer.borderColor = UIColor.black.withAlphaComponent(0.55).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)
        buildLayout()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped)))
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        let logo = CompanyLogo.make(for: card.company, size: 52)

        let title = UILabel()
        title.numberOfLines = 2
        title.attributedText = NSAttributedString(
            string: "\(card.company) \(card.title)",
            attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: Theme.linkBlue
            ])

        let topRow = UIStackView(arrangedSubviews: [logo, title])
        topRow.spacing = 12
        topRow.alignment = .center

        let location = makeLabel(card.location, size: 10)

        let descHeader = makeLabel("Job Description", size: 12, weight: .bold)
        let descBody = makeLabel(card.description, size: 10, lines: 5)
        descBody.lineBreakMode = .byTruncatingTail
        let descStack = UIStackView(arrangedSubviews: [descHeader, descBody])
        descStack.axis = .vertical
        descStack.spacing = 6

        let ring = MatchRingView(percent: card.matchPercent)
        ring.widthAnchor.constraint(equalToConstant: 96).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let midRow = UIStackView(arrangedSubviews: [descStack, ring])
        midRow.spacing = 10
        midRow.alignment = .center

        let kwHeader = makeLabel("Matching Key Words", size: 12, weight: .bold)
        let chipRow = UIStackView(arrangedSubviews: card.keywords.prefix(4).map { makeChip($0) })
        chipRow.spacing = 6
        chipRow.distribution = .fillProportionally
        let more = makeLabel("+ \(card.extraKeywords) more...", size: 8, color: .darkGray)

        let salaryHeader = makeLabel("Salary", size: 12, weight: .bold)
        let salary = makeLabel(card.salary, size: 8)
        let salaryStack = UIStackView(arrangedSubviews: [salaryHeader, salary])
        salaryStack.axis = .vertical
        salaryStack.spacing = 4

        heartButton.tintColor = Theme.heartRed
        heartButton.addTarget(self, action: #selector(heartTapped), for: .touchUpInside)
        setLiked(false)

        let bottomRow = UIStackView(arrangedSubviews: [salaryStack, UIView(), heartButton])
        bottomRow.alignment = .bottom

        let root = UIStackView(arrangedSubviews: [topRow, location, midRow, kwHeader, chipRow, more, UIView(), bottomRow])
        root.axis = .vertical
        root.spacing = 10
        root.setCustomSpacing(4, after: topRow)
        root.setCustomSpacing(6, after: kwHeader)
        root.setCustomSpacing(4, after: chipRow)
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor, constant: 36),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24)
        ])
    }

    func setLiked(_ liked: Bool) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        heartButton.setImage(UIImage(systemName: liked ? "heart.fill" : "heart", withConfiguration: cfg), for: .normal)
    }

    @objc private func heartTapped() { onHeartTapped?() }
    @objc private func cardTapped() { onTapped?() }

    /// depth 0 = top card (straight); deeper cards fan out behind it.
    func applyStackTransform(depth: Int) {
        guard depth > 0 else { transform = .identity; return }
        let sign: CGFloat = depth % 2 == 0 ? -1 : 1
        let angle = sign * CGFloat(depth) * (.pi / 60)
        transform = CGAffineTransform(rotationAngle: angle)
    }
}
