////
//  SavedJobStore.swift
//  JobShop
//
//  Created by Risha V on 10/21/26.
//
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

extension Notification.Name {
    static let savedJobsChanged = Notification.Name("savedJobsChanged")
}


class SavedJobsStore {
    static let shared = SavedJobsStore()

    private(set) var jobs: [JobCard] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    private init() {
        // Restart the listener whenever the account changes (login / logout)
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.startListening(uid: user?.uid)
        }
    }

    // MARK: Public API (unchanged signatures)

    func contains(_ job: JobCard) -> Bool {
        let key = Self.key(for: job)
        return jobs.contains { Self.key(for: $0) == key }
    }

    func save(_ job: JobCard) {
        guard !contains(job) else { return }
        jobs.insert(job, at: 0)                       // optimistic local update
        notify()
        collection()?.document(Self.key(for: job)).setData(Self.encode(job)) { error in
            if let error { print("Save failed: \(error.localizedDescription)") }
        }
    }

    func remove(_ job: JobCard) {
        let key = Self.key(for: job)
        jobs.removeAll { Self.key(for: $0) == key }
        notify()
        collection()?.document(key).delete { error in
            if let error { print("Delete failed: \(error.localizedDescription)") }
        }
    }

    func updateStatus(_ status: ApplicationStatus, for job: JobCard) {
        let key = Self.key(for: job)
        guard let i = jobs.firstIndex(where: { Self.key(for: $0) == key }) else { return }
        jobs[i].status = status
        notify()
        collection()?.document(key).updateData(["status": status.rawValue]) { error in
            if let error { print("Status update failed: \(error.localizedDescription)") }
        }
    }

    func savedVersion(of job: JobCard) -> JobCard? {
        let key = Self.key(for: job)
        return jobs.first { Self.key(for: $0) == key }
    }

    /// Sample data is no longer used. Safe to delete this stub once nothing calls it.
    func loadSamples() {}

    private func notify() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .savedJobsChanged, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .savedJobsChanged, object: nil)
            }
        }
    }

    // MARK: Firestore

    private func collection() -> CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("accounts").document(uid).collection("savedJobs")
    }

    private func startListening(uid: String?) {
        listener?.remove()
        listener = nil
        jobs = []
        notify()
        guard let uid else { return }

        listener = db.collection("accounts").document(uid).collection("savedJobs")
            .order(by: "savedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else {
                    if let error { print("Listen failed: \(error.localizedDescription)") }
                    return
                }
                self.jobs = snapshot.documents.compactMap { Self.decode($0.data()) }
                self.notify()
            }
    }

    // MARK: Encoding

    /// Stable key so the same job maps to the same document on every launch.
    /// (JobCard.id is likely regenerated each launch, so it isn't used for Firestore.)
    private static func key(for job: JobCard) -> String {
        "\(job.company)_\(job.title)".lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    private static func encode(_ j: JobCard) -> [String: Any] {
        [
            "company": j.company,
            "title": j.title,
            "location": j.location,
            "description": j.description,
            "matchPercent": j.matchPercent,
            "keywords": j.keywords,
            "extraKeywords": j.extraKeywords,
            "salary": j.salary,
            "dateApplied": j.dateApplied,
            "status": j.status.rawValue,
            "applyURL": j.applyURL?.absoluteString ?? "",
            "savedAt": FieldValue.serverTimestamp()
        ]
    }

    private static func decode(_ d: [String: Any]) -> JobCard? {
        guard let company = d["company"] as? String,
              let title = d["title"] as? String else { return nil }
        let status = (d["status"] as? String).flatMap(ApplicationStatus.init(rawValue:)) ?? .notApplied
        return JobCard(
            company: company,
            title: title,
            location: d["location"] as? String ?? "",
            description: d["description"] as? String ?? "",
            matchPercent: d["matchPercent"] as? Int ?? 0,
            keywords: d["keywords"] as? [String] ?? [],
            extraKeywords: d["extraKeywords"] as? Int ?? 0,
            salary: d["salary"] as? String ?? "",
            dateApplied: d["dateApplied"] as? String ?? "",
            status: status,
            applyURL: URL(string: d["applyURL"] as? String ?? ""))
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
