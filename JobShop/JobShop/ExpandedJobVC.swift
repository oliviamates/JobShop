//
//  ExpandedJobVC.swift
//  JobShop
//
//  Created by Risha V on 10/21/26.
//
import UIKit
 
class ExpandedJobVC: UIViewController {
 
    private var job: JobCard
    private let store = SavedJobsStore.shared
    private let heartButton = UIButton(type: .system)
    private let statusButton = UIButton(type: .system)
 
    init(job: JobCard) {
        // If it's already saved, show the saved copy (it may have an updated status).
        self.job = SavedJobsStore.shared.savedVersion(of: job) ?? job
        super.init(nibName: nil, bundle: nil)
    }
 
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
 
        let header = addHeaderBar()
        let menu = makeMenuButton()

        header.addSubview(menu)
        NSLayoutConstraint.activate([
            menu.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            menu.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
 
        buildContent(below: header)
    }
 
    // MARK: Layout
 
    private func buildContent(below header: UIView) {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
 
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.black.withAlphaComponent(0.55).cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 6
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 28),
            card.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -28),
            card.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            card.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
 
        // Date matched + heart
        let dateLabel = makeLabel("Date Matched: \(job.dateMatched)", size: 14)
        heartButton.addTarget(self, action: #selector(toggleSaved), for: .touchUpInside)
        refreshHeart()
        let dateRow = UIStackView(arrangedSubviews: [dateLabel, UIView(), heartButton])
        dateRow.alignment = .center
 
        // Logo / title / apply / ring
        let logo = CompanyLogo.make(for: job.company, size: 56)
        let title = makeLabel("\(job.company) \(job.title)", size: 17, weight: .bold)
        let location = makeLabel(job.location, size: 14)
        let applyRow = UIStackView(arrangedSubviews: [makeApplyButton(), UIView()])
        let info = UIStackView(arrangedSubviews: [title, location, applyRow])
        info.axis = .vertical
        info.spacing = 4
 
        let ring = MatchRingView(percent: job.matchPercent, lineWidth: 8, fontSize: 22)
        ring.widthAnchor.constraint(equalToConstant: 84).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 84).isActive = true
 
        let headRow = UIStackView(arrangedSubviews: [logo, info, ring])
        headRow.spacing = 10
        headRow.alignment = .center
 
        // Description
        let descHeader = makeLabel("Job Description", size: 15, weight: .bold)
        let descBody = makeLabel(job.description, size: 11)
 
        // Keywords
        let kwHeader = makeLabel("Matching Key Words", size: 15, weight: .bold)
        let chips = makeChipRows(maxWidth: UIScreen.main.bounds.width - 40 - 48)
        let more = makeLabel("+ \(job.extraKeywords) more...", size: 9, color: .darkGray)
 
        // Salary
        let salaryHeader = makeLabel("Salary", size: 15, weight: .bold)
        let salary = makeLabel(job.salary, size: 10)
 
        // Update status
        let statusLabel = makeLabel("Update Status:", size: 15, weight: .bold)
        statusButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        refreshStatusButton()
        let statusRow = UIStackView(arrangedSubviews: [statusLabel, statusButton])
        statusRow.spacing = 10
        statusRow.alignment = .center
 
        let root = UIStackView(arrangedSubviews: [dateRow, headRow, descHeader, descBody,
                                                  kwHeader, chips, more, salaryHeader, salary, statusRow])
        root.axis = .vertical
        root.spacing = 10
        root.setCustomSpacing(16, after: headRow)
        root.setCustomSpacing(4, after: descHeader)
        root.setCustomSpacing(18, after: descBody)
        root.setCustomSpacing(6, after: kwHeader)
        root.setCustomSpacing(4, after: chips)
        root.setCustomSpacing(14, after: more)
        root.setCustomSpacing(4, after: salaryHeader)
        root.setCustomSpacing(18, after: salary)
        root.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            root.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            root.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24)
        ])
    }
 
    /// Chips that wrap onto multiple rows.
    private func makeChipRows(maxWidth: CGFloat) -> UIView {
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 6
        rows.alignment = .leading
 
        func newRow() -> UIStackView {
            let r = UIStackView()
            r.spacing = 6
            return r
        }
 
        var row = newRow()
        var used: CGFloat = 0
        for kw in job.keywords {
            let w = (kw as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 11)]).width + 16
            if used + w > maxWidth && !row.arrangedSubviews.isEmpty {
                rows.addArrangedSubview(row)
                row = newRow()
                used = 0
            }
            row.addArrangedSubview(makeChip(kw, fontSize: 11))
            used += w + 6
        }
        if !row.arrangedSubviews.isEmpty { rows.addArrangedSubview(row) }
        return rows
    }
 
    private func makeApplyButton() -> UIButton {
        var c = UIButton.Configuration.filled()
        c.title = "Apply!"
        c.image = UIImage(systemName: "arrow.up.right.square")
        c.imagePlacement = .trailing
        c.imagePadding = 4
        c.baseBackgroundColor = Theme.ringGreen
        c.baseForegroundColor = .black
        c.cornerStyle = .capsule
        c.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = .systemFont(ofSize: 12, weight: .medium)
            return a
        }
        return UIButton(configuration: c, primaryAction: UIAction { [weak self] _ in
            guard let url = self?.job.applyURL else { return }
            UIApplication.shared.open(url)
        })
    }
 
    // MARK: Heart (save / unsave)
 
    private func refreshHeart() {
        let saved = store.contains(job)
        let cfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        heartButton.setImage(UIImage(systemName: saved ? "heart.fill" : "heart", withConfiguration: cfg), for: .normal)
        heartButton.tintColor = Theme.heartRed
    }
 
    @objc private func toggleSaved() {
        if store.contains(job) { store.remove(job) } else { store.save(job) }
        refreshHeart()
    }
 
    // MARK: Status
 
    private func refreshStatusButton() {
        var c = UIButton.Configuration.filled()
        c.title = job.status.rawValue
        c.baseBackgroundColor = job.status.color
        c.baseForegroundColor = .black
        c.cornerStyle = .capsule
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = .systemFont(ofSize: 12, weight: .medium)
            return a
        }
        statusButton.configuration = c
        statusButton.menu = UIMenu(children: ApplicationStatus.allCases.map { status in
            UIAction(title: status.rawValue, state: status == self.job.status ? .on : .off) { [weak self] _ in
                self?.setStatus(status)
            }
        })
        statusButton.showsMenuAsPrimaryAction = true
    }
 
    private func setStatus(_ status: ApplicationStatus) {
        job.status = status
        // Tracking an application implies you want it saved.
        if !store.contains(job) { store.save(job) }
        store.updateStatus(status, for: job)
        refreshStatusButton()
        refreshHeart()
    }
}

