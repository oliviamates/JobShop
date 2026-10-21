//
//  SavedJobStore.swift
//  JobShop
//
//  Created by Risha V on 10/21/26.
//
//

import UIKit

extension Notification.Name {
    static let savedJobsChanged = Notification.Name("savedJobsChanged")
}


class SavedJobsStore {
    static let shared = SavedJobsStore()
    private init() {}

    private(set) var jobs: [JobCard] = []

    func contains(_ job: JobCard) -> Bool {
        jobs.contains { $0.id == job.id }
    }

    func save(_ job: JobCard) {
        guard !contains(job) else { return }
        jobs.insert(job, at: 0)
        notify()
    }

    func remove(_ job: JobCard) {
        jobs.removeAll { $0.id == job.id }
        notify()
    }

    func updateStatus(_ status: ApplicationStatus, for job: JobCard) {
        guard let i = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[i].status = status
        notify()
    }

    func savedVersion(of job: JobCard) -> JobCard? {
        jobs.first { $0.id == job.id }
    }

    private func notify() {
        NotificationCenter.default.post(name: .savedJobsChanged, object: nil)
    }

    func loadSamples() {
        guard jobs.isEmpty else { return }
        jobs = [
            JobCard(company: "Google", title: "Software Engineer", location: "San Francisco, CA",
                    description: "Build scalable systems used by billions.", matchPercent: 30,
                    keywords: ["Java", "Python", "JavaScript", "iOS Development"], extraKeywords: 10,
                    salary: "$109000 - $150000 annually", dateApplied: "September 15th, 2026",
                    status: .notApplied, applyURL: URL(string: "https://careers.google.com")),
            JobCard(company: "AWS", title: "Data Architect", location: "Seattle, WA",
                    description: "Design data platforms on AWS.", matchPercent: 50,
                    keywords: ["SQL", "Python", "AWS", "Spark"], extraKeywords: 6,
                    salary: "$125000 - $170000 annually", dateApplied: "September 20th, 2026",
                    status: .interviewed, applyURL: URL(string: "https://www.amazon.jobs")),
            JobCard(company: "VISA", title: "Software Engineer", location: "Austin, TX",
                    description: "Build payment infrastructure.", matchPercent: 20,
                    keywords: ["Java", "Spring", "SQL", "Kafka"], extraKeywords: 9,
                    salary: "$105000 - $145000 annually", dateApplied: "September 27th, 2026",
                    status: .applied, applyURL: URL(string: "https://usa.visa.com/careers")),
            JobCard(company: "Roblox", title: "Data Analyst", location: "Chicago, IL",
                    description: "Turn player data into insights.", matchPercent: 85,
                    keywords: ["SQL", "Python", "Tableau", "Statistics"], extraKeywords: 4,
                    salary: "$95000 - $130000 annually", dateApplied: "September 27th, 2026",
                    status: .offer, applyURL: URL(string: "https://careers.roblox.com")),
            JobCard(company: "Jane Street", title: "Quantum Analyst", location: "New York City, NY",
                    description: "Research and trading analytics.", matchPercent: 10,
                    keywords: ["OCaml", "Python", "Math"], extraKeywords: 5,
                    salary: "$150000 - $220000 annually", dateApplied: "October 2nd, 2026",
                    status: .notApplied, applyURL: URL(string: "https://www.janestreet.com/join-jane-street"))
        ]
        notify()
    }
}

// MARK: - Tabs

enum AppDestination: Int {
    case matches = 0
    case saved = 1
    case settings = 2
}


extension UIViewController {

    @discardableResult
    func addHeaderBar() -> UIView {
        let header = UIView()
        header.backgroundColor = .white
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 64)
        ])
        return header
    }


    
    func makeNavMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Your Matches", image: UIImage(systemName: "rectangle.stack"),
                     state: self is MatchesVC ? .on : .off) { [weak self] _ in self?.navigate(to: .matches) },
            UIAction(title: "Saved Jobs", image: UIImage(systemName: "heart"),
                     state: self is SavedJobsVC ? .on : .off) { [weak self] _ in self?.navigate(to: .saved) },
            UIAction(title: "Settings", image: UIImage(systemName: "gearshape"),
                     state: self is SettingsVC ? .on : .off) { [weak self] _ in self?.navigate(to: .settings) },
        ])
    }

    func makeMenuButton() -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "line.3.horizontal")
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let button = UIButton(configuration: config, primaryAction: nil)
        button.tintColor = .black
        button.translatesAutoresizingMaskIntoConstraints = false
        button.menu = makeNavMenu()
        button.showsMenuAsPrimaryAction = true
        
        return button
    }


    func makeMenuBarButtonItem() -> UIBarButtonItem {
        let item = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"), menu: makeNavMenu())
        item.tintColor = .black
        return item
    }

    func navigate(to destination: AppDestination) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        let vc: UIViewController?
        switch destination {
        case .matches:
            if self is MatchesVC { return }   // already here
            vc = storyboard.instantiateViewController(withIdentifier: "MatchesVC")
        case .saved:
            if self is SavedJobsVC { return }
            vc = storyboard.instantiateViewController(withIdentifier: "SavedJobsVC")
        case .settings:
            if self is SettingsVC { return }
            vc = storyboard.instantiateViewController(withIdentifier: "SettingsVC")
        }

        guard let vc, let nav = navigationController else { return }
        nav.setViewControllers([vc], animated: true)
    }
}
