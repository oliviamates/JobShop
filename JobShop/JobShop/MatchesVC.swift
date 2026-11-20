//
//  MatchesVC.swift
//  JobShop
//
//

import UIKit
import UserNotifications
import EventKit
import EventKitUI
import FirebaseFirestore
import FirebaseAuth


private enum PayRange: String, CaseIterable {
    case under50 = "Under $50k"
    case from50 = "$50k - $80k"
    case from80 = "$80k - $120k"
    case over120 = "$120k+"

    func contains(_ salary: Int) -> Bool {
        switch self {
        case .under50: return salary < 50_000
        case .from50: return (50_000..<80_000).contains(salary)
        case .from80: return (80_000..<120_000).contains(salary)
        case .over120: return salary >= 120_000
        }
    }

    var minimum: Int? {
        switch self {
        case .under50: return nil
        case .from50: return 50_000
        case .from80: return 80_000
        case .over120: return 120_000
        }
    }
}

private enum Recency: String, CaseIterable {
    case day = "Past 24 hours"
    case threeDays = "Past 3 days"
    case week = "Past week"
    case month = "Past 30 days"

    var days: Int {
        switch self {
        case .day: return 1
        case .threeDays: return 3
        case .week: return 7
        case .month: return 30
        }
    }
}

private struct JobFilters {
    var jobType: String?
    var location: String?
    var industry: String?
    var payRange: PayRange?
    var workMode: String?
    var recency: Recency?

    var isActive: Bool {
        jobType != nil || location != nil || industry != nil
            || payRange != nil || workMode != nil || recency != nil
    }

    private static let categoryTags: [String: String] = [
        "Accounting": "accounting-finance-jobs", "Finance": "accounting-finance-jobs",
        "Engineering": "engineering-jobs", "Information Technology": "it-jobs",
        "Health Care Service": "healthcare-nursing-jobs", "Medical Science": "healthcare-nursing-jobs",
        "Human Resources": "hr-jobs", "Law": "legal-jobs",
        "Marketing/Advertising": "pr-advertising-marketing-jobs", "Sales": "sales-jobs",
        "Teaching/Education": "teaching-jobs", "Retail": "retail-jobs",
        "Hospitality & Tourism": "hospitality-catering-jobs", "Culinary Art": "hospitality-catering-jobs",
        "Construction/Woodwork": "trade-construction-jobs", "Manufacturing": "manufacturing-jobs",
        "Transportation/Machine Operation": "logistics-warehouse-jobs", "Consulting": "consultancy-jobs",
        "Real Estate": "property-jobs", "Social Service": "social-work-jobs",
        "Nonprofit & Philanthropy": "charity-voluntary-jobs", "Applied Arts and Design": "creative-design-jobs",
        "Visual Arts": "creative-design-jobs", "Office Work": "admin-jobs",
        "Energy": "energy-oil-gas-jobs", "Life Science": "scientific-qa-jobs",
        "Physical Science": "scientific-qa-jobs"
    ]

    func toSearchFilters() -> JobSearchFilters {
        var f = JobSearchFilters()
        f.location = location
        f.maxDaysOld = recency?.days
        f.salaryMin = payRange?.minimum

        if let jobType {
            switch jobType {
            case "Full-Time": f.fullTime = true
            case "Part-Time": f.partTime = true
            case "Contract": f.contract = true
            default: f.requiredTerms.append(jobType.lowercased())   // Internship, Freelance, ...
            }
        }

        if let industry {
            if let tag = Self.categoryTags[industry] {
                f.categoryTag = tag
            } else {
                let firstWord = industry.lowercased()
                    .components(separatedBy: CharacterSet(charactersIn: "/& "))
                    .first { !$0.isEmpty } ?? industry
                f.requiredTerms.append(firstWord)
            }
        }

        // The API has no remote flag, so work mode is a keyword search.
        switch workMode {
        case "Remote": f.requiredTerms.append("remote")
        case "Hybrid": f.requiredTerms.append("hybrid")
        case "On-site": f.excludedTerms += ["remote", "hybrid"]
        default: break
        }
        return f
    }

    private static func salaryValue(_ text: String) -> Int? {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        guard let range = cleaned.range(of: "\\d+", options: .regularExpression),
              let n = Int(cleaned[range]), n > 0 else { return nil }
        return n
    }

    func matches(_ job: JobCard) -> Bool {
        guard let payRange else { return true }
        guard let salary = Self.salaryValue(job.salary), payRange.contains(salary) else { return false }
        return true
    }
}

class MatchesVC: UIViewController, EKEventEditViewDelegate {
    let eventStore = EKEventStore()

    private var cardsData: [JobCard] = []
    private var allCards: [JobCard] = []

    private var pool: [JobCard] = []
    private var poolIndex = 0
    private let batchSize = 5
    private var loginCount = 0
    private var loginCountLoaded = false

    private var dismissedKeys: Set<String> = []

    private let recommendedThreshold = 40

    private var basePool: [JobCard] = []
    private var filters = JobFilters()
    private var locationOptions: [String] = []
    private var loadGeneration = 0

    private var isSwiping = false
    private let store = SavedJobsStore.shared
    private var cardViews: [CardView] = []
    private let containerView = UIView()
    @IBOutlet weak var menuButton: UIBarButtonItem?

    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Theme.background
        if let menuButton {
            menuButton.menu = makeNavMenu()              // storyboard button
        } else {
            navigationItem.rightBarButtonItem = makeMenuBarButtonItem()   // created in code
        }
        ensureTitleExists()
        setupFilterMenu()
        setupContainer()

        // Saved jobs load asynchronously from Firestore, so rebuild the deck whenever they change.
        NotificationCenter.default.addObserver(self, selector: #selector(savedJobsChanged),
                                               name: .savedJobsChanged, object: nil)
        loadJobs()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        loadCalendarPreference()
        refreshDeck()
    }


    private func loadJobs() {
        emptyLabel.text = "Loading matches..."
        emptyLabel.isHidden = false

        loadGeneration += 1
        let generation = loadGeneration

        Task { [weak self] in
            guard let self else { return }
            do {
                if !self.loginCountLoaded {
                    self.loginCount = await self.fetchLoginCount()
                    self.loginCountLoaded = true
                    self.setupFilterMenu()
                }

                let jobs = try await JobService.shared.fetchJobs(filters: self.filters.toSearchFilters(), count: 100)
                // A newer filter change started another load; drop this stale result.
                guard generation == self.loadGeneration else { return }

                // Location choices come from the unfiltered results, so they don't shrink after you pick one.
                if self.filters.location == nil {
                    self.locationOptions = Array(Set(jobs.map(\.location)))
                        .filter { !$0.isEmpty && $0 != "Location not listed" }
                        .sorted()
                }

                let usable = self.filters.isActive
                    ? jobs
                    : jobs.filter { $0.matchPercent >= self.recommendedThreshold }
                self.basePool = usable
                    .filter { self.filters.matches($0) }
                    .sorted { $0.matchPercent > $1.matchPercent }
                self.rebuildPool()
                self.setupFilterMenu()
            } catch {
                guard generation == self.loadGeneration else { return }
                print("Failed to load jobs: \(error)")
                self.emptyLabel.text = "Couldn't load jobs.\nCheck your connection and try again."
            }
            self.refreshDeck()
        }
    }

    private let emptyMessage = "No recommended matches right now.\nCheck back later for new ones!"

    private func loadCalendarPreference() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore()
            .collection("accounts")
            .document(uid)
            .getDocument { snapshot, error in

                if let error {
                    print("\(error.localizedDescription)")
                    return
                }

                let data = snapshot?.data() ?? [:]
                globalCal = data["calendarEnabled"] as? Bool ?? false
            }
    }

    private func fetchLoginCount() async -> Int {
        guard let uid = Auth.auth().currentUser?.uid else {
            return 0
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("accounts")
                .document(uid)
                .getDocument()

            return snapshot.data()?["loginCount"] as? Int ?? 0

        } catch {
            print("Failed to fetch login count: \(error)")
            return 0
        }
    }

    private func key(_ card: JobCard) -> String {
        "\(card.company)|\(card.title)"
    }

    @discardableResult
    private func loadNextBatch() -> Bool {
        var batch: [JobCard] = []
        while poolIndex < pool.count && batch.count < batchSize {
            let job = pool[poolIndex]
            poolIndex += 1
            if !store.contains(job) && !dismissedKeys.contains(key(job)) {
                batch.append(job)
            }
        }
        guard !batch.isEmpty else { return false }
        allCards.append(contentsOf: batch)
        cardsData = batch
        return true
    }

    @objc private func savedJobsChanged() {
        guard !isSwiping else { return }
        refreshDeck()
    }

    private func refreshDeck() {
        cardsData.removeAll { store.contains($0) || dismissedKeys.contains(key($0)) }
        for card in allCards where !store.contains(card)
            && !dismissedKeys.contains(key(card))
            && filters.matches(card)
            && !cardsData.contains(where: { key($0) == key(card) }) {
            cardsData.insert(card, at: 0)
        }
        if cardsData.isEmpty { loadNextBatch() }
        layoutDeckStack()
        // Refresh heart state in case something was (un)saved on another screen.
        for cardView in cardViews { cardView.setLiked(store.contains(cardView.card)) }
    }

    private func ensureTitleExists() {
        guard titleLabel == nil else { return }

        let label = UILabel()
        label.text = "Your Matches!"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = Theme.green
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36)
        ])

        self.titleLabel = label
    }


    private let jobTypeOptions = [
        "Full-Time", "Part-Time", "Internship", "Co-op", "Contract",
        "Temporary", "Freelance", "Seasonal", "Apprenticeship"
    ]

    private let workModeOptions = ["Remote", "Hybrid", "On-site"]

    private let industryOptions = [
        "Accounting", "Agriculture", "Animal Service", "Applied Arts and Design", "Athletics",
        "Business Initiatives", "Construction/Woodwork", "Creative Writing", "Culinary Art",
        "Engineering", "Finance", "Health Care Service", "Human Resources", "Humanities",
        "Information Technology", "Law", "Life Science", "Management/Administration",
        "Marketing/Advertising", "Mathematics/Statistics", "Mechanics/Electronics", "Media",
        "Medical Science", "Music", "Nature/Outdoors", "Office Work", "Performing Arts",
        "Personal Service", "Physical Science", "Physical/Manual Labor", "Politics",
        "Professional Advising", "Protective Service", "Public Speaking", "Religious Activities",
        "Retail", "Sales", "Social Science", "Social Service", "Teaching/Education",
        "Transportation/Machine Operation", "Visual Arts",
        "Aerospace & Defense", "Automotive", "Biotechnology", "Consulting", "Energy",
        "Entertainment", "Environmental Services", "Government & Public Administration",
        "Hospitality & Tourism", "Insurance", "Manufacturing", "Nonprofit & Philanthropy",
        "Pharmaceuticals", "Real Estate", "Telecommunications"
    ]

    private func rebuildPool() {
        pool = basePool
        poolIndex = 0
        emptyLabel.text = filters.isActive
            ? "No matches for these filters.\nTry clearing a filter."
            : emptyMessage
    }

    /// Called whenever a filter changes: clear the deck and fetch fresh results from the API.
    private func applyFilters() {
        allCards.removeAll()
        cardsData.removeAll()
        basePool.removeAll()
        pool.removeAll()
        poolIndex = 0
        setupFilterMenu()      // refresh checkmarks and the Clear item
        layoutDeckStack()
        loadJobs()
    }

    /// A submenu with an "Any" row plus one row per option; the selected one gets a checkmark.
    private func optionMenu(_ title: String, options: [String], selected: String?,
                            onSelect: @escaping (String?) -> Void) -> UIMenu {
        var items: [UIMenuElement] = [
            UIAction(title: "Any", state: selected == nil ? .on : .off) { _ in onSelect(nil) }
        ]
        items += options.map { option in
            UIAction(title: option, state: selected == option ? .on : .off) { _ in onSelect(option) }
        }
        return UIMenu(title: selected.map { "\(title): \($0)" } ?? title, children: items)
    }

    private func lockedItem(_ title: String) -> UIAction {
        UIAction(title: title, image: UIImage(systemName: "lock"), attributes: .disabled) { _ in }
    }

    private func setupFilterMenu() {
        let payRangeUnlocked = loginCount >= 5
        let jobModalUnlocked = loginCount >= 15

        var children: [UIMenuElement] = [
            optionMenu("Job Type", options: jobTypeOptions, selected: filters.jobType) { [weak self] in
                self?.filters.jobType = $0
                self?.applyFilters()
            },
            optionMenu("Location", options: locationOptions, selected: filters.location) { [weak self] in
                self?.filters.location = $0
                self?.applyFilters()
            },
            optionMenu("Industry", options: industryOptions, selected: filters.industry) { [weak self] in
                self?.filters.industry = $0
                self?.applyFilters()
            }
        ]

        children.append(payRangeUnlocked
            ? optionMenu("Pay Range", options: PayRange.allCases.map(\.rawValue),
                         selected: filters.payRange?.rawValue) { [weak self] in
                self?.filters.payRange = $0.flatMap(PayRange.init(rawValue:))
                self?.applyFilters()
            }
            : lockedItem("Pay Range"))

        // Recency now maps to the API's max listing age. Gate it with loginCount like the others if you want.
        children.append(optionMenu("Recency", options: Recency.allCases.map(\.rawValue),
                                   selected: filters.recency?.rawValue) { [weak self] in
            self?.filters.recency = $0.flatMap(Recency.init(rawValue:))
            self?.applyFilters()
        })

        children.append(jobModalUnlocked
            ? optionMenu("Job Modal", options: workModeOptions, selected: filters.workMode) { [weak self] in
                self?.filters.workMode = $0
                self?.applyFilters()
            }
            : lockedItem("Job Modal"))

        if filters.isActive {
            let clear = UIAction(title: "Clear Filters",
                                 image: UIImage(systemName: "xmark.circle"),
                                 attributes: .destructive) { [weak self] _ in
                self?.filters = JobFilters()
                self?.applyFilters()
            }
            children.append(UIMenu(options: .displayInline, children: [clear]))
        }

        let filterMenu = UIMenu(children: children)

        if let filterButton = filterButton {
            filterButton.menu = filterMenu
            filterButton.showsMenuAsPrimaryAction = true

        } else {
            let codeFilterButton = UIButton(type: .system)

            codeFilterButton.setTitle("Filter ", for: .normal)
            codeFilterButton.setImage(
                UIImage(systemName: "line.3.horizontal.decrease.circle"),
                for: .normal
            )

            codeFilterButton.menu = filterMenu
            codeFilterButton.showsMenuAsPrimaryAction = true

            navigationItem.leftBarButtonItem =
                UIBarButtonItem(customView: codeFilterButton)
        }
    }

    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Anchor the deck under the title (search bar is gone).
        let topAnchor = titleLabel?.bottomAnchor ?? view.safeAreaLayoutGuide.topAnchor
        let topConstant: CGFloat = titleLabel != nil ? 24 : 120

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: topConstant),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1.1)
        ])
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }

    private func layoutDeckStack() {
        cardViews.forEach { $0.removeFromSuperview() }
        cardViews.removeAll()

        // The last view added sits on top, so sort ascending:
        // the highest-scoring job is added last and ends up as the top card.
        let ordered = cardsData.sorted { $0.matchPercent < $1.matchPercent }

        for data in ordered {
            let cardView = CardView(card: data)
            cardView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(cardView)
            NSLayoutConstraint.activate([
                cardView.topAnchor.constraint(equalTo: containerView.topAnchor),
                cardView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                cardView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                cardView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            cardView.setLiked(store.contains(data))
            cardViews.append(cardView)
        }

        for (i, cardView) in cardViews.enumerated() {
            cardView.applyStackTransform(depth: cardViews.count - 1 - i)
        }
        emptyLabel.isHidden = !cardsData.isEmpty
        setupTopCardGesture()
    }

    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        controller.dismiss(animated: true, completion: nil)

        switch action {
        case .canceled:
            print("User cancelled adding the event.")
        case .saved:
            print("Event was successfully saved to the calendar!")
        case .deleted:
            print("Event was deleted.")
        @unknown default:
            break
        }
    }

    private func setupTopCardGesture() {
        guard let topCard = cardViews.last else { return }
        topCard.gestureRecognizers?
            .filter { $0 is UIPanGestureRecognizer }
            .forEach { topCard.removeGestureRecognizer($0) }
        topCard.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:))))

        topCard.onTapped = { [weak self, weak topCard] in
            guard let self, let topCard else { return }
            self.navigationController?.pushViewController(ExpandedJobVC(job: topCard.card), animated: true)
        }

        topCard.onHeartTapped = { [weak self, weak topCard] in
            guard let self, let topCard else { return }
            self.animateSwipeOffScreen(targetCard: topCard, directionRight: true)
        }
    }

    func presentEventEditor(_ title: String) {
        let editVC = EKEventEditViewController()
        editVC.eventStore = self.eventStore
        editVC.editViewDelegate = self

        let event = EKEvent(eventStore: self.eventStore)
        event.title = "Apply to " + title
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(globalNotifChoice)
        event.isAllDay = true
        event.notes = "Log in to JobShop to continue your application!"

        editVC.event = event
        self.present(editVC, animated: true, completion: nil)
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let card = gesture.view as? CardView else { return }
        let t = gesture.translation(in: containerView)
        let v = gesture.velocity(in: containerView)

        switch gesture.state {
        case .changed:
            let strength = max(min(t.x / 300, 1), -1)
            let angle = (CGFloat.pi / 8) * strength
            card.transform = CGAffineTransform(rotationAngle: angle)
                .concatenating(CGAffineTransform(translationX: t.x, y: t.y))
        case .ended:
            let distance: CGFloat = 100
            let flick: CGFloat = 800
            if t.x > distance || v.x > flick {
                animateSwipeOffScreen(targetCard: card, directionRight: true)
            } else if t.x < -distance || v.x < -flick {
                animateSwipeOffScreen(targetCard: card, directionRight: false)
            } else {
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.65,
                               initialSpringVelocity: 0.8, options: .allowUserInteraction) {
                    card.applyStackTransform(depth: 0)
                }
            }
        default:
            break
        }
    }

    private func animateSwipeOffScreen(targetCard: CardView, directionRight: Bool) {
        isSwiping = true
        targetCard.isUserInteractionEnabled = false

        if directionRight {
            targetCard.setLiked(true)
            store.save(targetCard.card)   // writes to Firestore
            scheduleReminder(for: targetCard.card)
            if globalCal {
                presentEventEditor(targetCard.card.company)
            }
        }

        let exitX = directionRight ? view.frame.width + 150 : -view.frame.width - 150
        UIView.animate(withDuration: 0.3, animations: {
            targetCard.transform = CGAffineTransform(translationX: exitX, y: targetCard.transform.ty)
            targetCard.alpha = 0
        }) { [weak self] _ in
            self?.recycleCard(targetCard, dismissed: !directionRight)
        }
    }

    private func scheduleReminder(for job: JobCard) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore()
            .collection("accounts")
            .document(uid)
            .getDocument { snapshot, error in

                if let error {
                    print("\(error.localizedDescription)")
                    return
                }

                let data = snapshot?.data() ?? [:]
                let enabled = data["remindersEnabled"] as? Bool ?? false
                let choice = data["notifChoice"] as? Int ?? 86400

                globalReminders = enabled
                globalNotifChoice = Double(choice)

                // don't schedule anything if reminders are disabled
                guard enabled else { return }

                let content = UNMutableNotificationContent()
                content.title = "JobShop Application Reminder"
                content.body = "Apply to \(job.title) at \(job.company)!"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: Double(choice),
                    repeats: false
                )

                let identifier = "jobshop-\(job.company)-\(job.title)"

                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().add(request) { error in
                    if let error {
                        print("Notification scheduling error: \(error.localizedDescription)")
                    } else {
                        print("Notification successfully scheduled!")
                    }
                }
            }
    }

    private func recycleCard(_ cardView: CardView, dismissed: Bool) {
        isSwiping = false
        let swipedKey = key(cardView.card)
        if dismissed { dismissedKeys.insert(swipedKey) }
        cardsData.removeAll { key($0) == swipedKey }

        if cardsData.isEmpty {
            refreshDeck()      // deals the next batch of 5, or shows the empty state
        } else {
            layoutDeckStack()
        }
    }

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "No recommended matches right now.\nCheck back later for new ones!"
        l.numberOfLines = 0
        l.textAlignment = .center
        l.textColor = .darkGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
}
