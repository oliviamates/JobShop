//
//  SavedJobsVC.swift
//  JobShop
//
//  Created by Risha V on 10/21/26.
//

import UIKit

class SavedJobsVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var titleJob: UILabel!
    private let store = SavedJobsStore.shared
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchField = UITextField()
    private let emptyLabel = UILabel()
    private var visibleJobs: [JobCard] = []
    private var query = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        let menu = makeMenuBarButtonItem()
        navigationItem.setHidesBackButton(true, animated: true)

        navigationItem.rightBarButtonItem = makeMenuBarButtonItem()

        let searchContainer = setupSearchRow(below: titleJob)
        setupTable(below: searchContainer)
        setupEmptyLabel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    // MARK: Search

    private func setupSearchRow(below header: UIView) -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.fieldGray
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let glass = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        glass.tintColor = .gray
        glass.translatesAutoresizingMaskIntoConstraints = false

        searchField.placeholder = "Search"
        searchField.font = .systemFont(ofSize: 13)
        searchField.returnKeyType = .done
        searchField.autocorrectionType = .no
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(glass)
        container.addSubview(searchField)

        let filter = UIButton(type: .system)   // visual only for now
        filter.setImage(UIImage(systemName: "line.3.horizontal.decrease",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)), for: .normal)
        filter.tintColor = .gray
        filter.backgroundColor = Theme.fieldGray
        filter.layer.cornerRadius = 15
        filter.layer.borderWidth = 1
        filter.layer.borderColor = UIColor.lightGray.cgColor
        filter.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filter)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            container.heightAnchor.constraint(equalToConstant: 32),
            container.trailingAnchor.constraint(equalTo: filter.leadingAnchor, constant: -14),

            filter.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            filter.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            filter.widthAnchor.constraint(equalToConstant: 30),
            filter.heightAnchor.constraint(equalToConstant: 30),

            glass.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            glass.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            glass.widthAnchor.constraint(equalToConstant: 14),
            glass.heightAnchor.constraint(equalToConstant: 14),

            searchField.leadingAnchor.constraint(equalTo: glass.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    @objc private func searchChanged() {
        query = searchField.text ?? ""
        reload()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }


    private func setupTable(below anchor: UIView) {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 130
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)
        tableView.register(SavedJobCell.self, forCellReuseIdentifier: SavedJobCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: anchor.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyLabel() {
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }

    private func reload() {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        visibleJobs = q.isEmpty ? store.jobs : store.jobs.filter {
            $0.company.lowercased().contains(q) ||
            $0.title.lowercased().contains(q) ||
            $0.location.lowercased().contains(q)
        }
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !visibleJobs.isEmpty
        emptyLabel.text = q_isEmpty
            ? "No saved jobs yet.\nSwipe right or tap the heart on a match!"
            : "No results."
    }

    private var q_isEmpty: Bool { query.trimmingCharacters(in: .whitespaces).isEmpty }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleJobs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SavedJobCell.reuseID, for: indexPath) as! SavedJobCell
        cell.configure(with: visibleJobs[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(ExpandedJobVC(job: visibleJobs[indexPath.row]), animated: true)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let remove = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, done in
            guard let self else { return }
            let job = self.visibleJobs[indexPath.row]
            self.store.remove(job)
            self.visibleJobs.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.updateEmptyState()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [remove])
    }
}

// MARK: - Row cell

final class SavedJobCell: UITableViewCell {
    static let reuseID = "SavedJobCell"
    private let card = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.black.withAlphaComponent(0.5).cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 4
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with job: JobCard) {
        card.subviews.forEach { $0.removeFromSuperview() }

        let logo = CompanyLogo.make(for: job.company, size: 44)

        let title = makeLabel("\(job.company) \(job.title)", size: 14, weight: .bold)
        let link = UIImageView(image: UIImage(systemName: "arrow.up.right.square"))
        link.tintColor = .black
        link.setContentHuggingPriority(.required, for: .horizontal)
        link.widthAnchor.constraint(equalToConstant: 13).isActive = true
        link.heightAnchor.constraint(equalToConstant: 13).isActive = true
        let titleRow = UIStackView(arrangedSubviews: [title, link, UIView()])
        titleRow.spacing = 4
        titleRow.alignment = .center

        let location = makeLabel(job.location, size: 11)
        let date = makeLabel("Date Applied: \(job.dateApplied)", size: 11)

        let statusKey = makeLabel("Status:", size: 11)
        let statusRow = UIStackView(arrangedSubviews: [statusKey, makeStatusPill(job.status), UIView()])
        statusRow.spacing = 8
        statusRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [titleRow, location, date, statusRow])
        textStack.axis = .vertical
        textStack.spacing = 5

        let ring = MatchRingView(percent: job.matchPercent, lineWidth: 6, fontSize: 14)
        ring.widthAnchor.constraint(equalToConstant: 62).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 62).isActive = true
        let caption = makeLabel("Match Score", size: 10, lines: 1)
        let ringStack = UIStackView(arrangedSubviews: [ring, caption])
        ringStack.axis = .vertical
        ringStack.alignment = .center
        ringStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [logo, textStack, ringStack])
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
    }

    private func makeStatusPill(_ status: ApplicationStatus) -> UIView {
        let label = makeLabel(status.rawValue, size: 10, weight: .medium, lines: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        let pill = UIView()
        pill.backgroundColor = status.color
        pill.layer.cornerRadius = 9
        pill.layer.borderWidth = 0.5
        pill.layer.borderColor = UIColor.darkGray.cgColor
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10)
        ])
        return pill
    }
}
