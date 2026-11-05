//
//  JobTypeVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 11/4/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class JobTypeVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var errorMessage: UILabel!
    
    let db = Firestore.firestore()

    var allJobTypes = [
        "Full-Time",
        "Part-Time",
        "Internship",
        "Co-op",
        "Contract",
        "Temporary",
        "Freelance",
        "Seasonal",
        "Apprenticeship"
    ]

    var filteredJobTypes = [String]()
    var savedJobTypes = [String]()
    var originalJobTypes = [String]()

    var isSearching: Bool {
        return !(searchBar.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        errorMessage.text = ""
        filteredJobTypes = allJobTypes
        loadSavedJobTypes()
    }
    
    @IBAction func savePressed(_ sender: Any) {
        errorMessage.text = ""

        guard let user = Auth.auth().currentUser else {
            errorMessage.text = "Error saving job types."
            return
        }

        db.collection("accounts").document(user.uid)
            .setData(["jobTypes": savedJobTypes], merge: true) { [weak self] err in

                guard let self = self else { return }

                if let err = err {
                    self.errorMessage.text = err.localizedDescription
                } else {
                    self.originalJobTypes = self.savedJobTypes
                    self.dismiss(animated: true)
                }
            }
    }

    @IBAction func cancelPressed(_ sender: Any) {
        savedJobTypes = originalJobTypes
        dismiss(animated: true)
    }

    func loadSavedJobTypes() {
        guard let user = Auth.auth().currentUser else {
            errorMessage.text = "Unable to load job types."
            return
        }

        db.collection("accounts").document(user.uid).getDocument { [weak self] document, err in

            guard let self = self else { return }

            if let err = err {
                self.errorMessage.text = err.localizedDescription
                return
            }

            if let data = document?.data() {
                self.savedJobTypes = data["jobTypes"] as? [String] ?? []
            } else {
                self.savedJobTypes = []
            }

            self.originalJobTypes = self.savedJobTypes
            self.tableView.reloadData()
        }
    }

    func addJobType(_ name: String) {
        errorMessage.text = ""

        if savedJobTypes.contains(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) {
            return
        }

        savedJobTypes.append(name)

        searchBar.text = ""
        searchBar.resignFirstResponder()

        filteredJobTypes = allJobTypes
        tableView.reloadData()
    }

    func removeJobType(at index: Int) {
        errorMessage.text = ""

        savedJobTypes.remove(at: index)
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filteredJobTypes = allJobTypes
        } else {
            filteredJobTypes = allJobTypes.filter { jobType in
                jobType.localizedCaseInsensitiveContains(searchText) &&
                !savedJobTypes.contains(where: {
                    $0.caseInsensitiveCompare(jobType) == .orderedSame
                })
            }
        }

        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return savedJobTypes.count
        }

        return isSearching ? filteredJobTypes.count : 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return savedJobTypes.isEmpty ? "No job types added yet" : "Your job types"
        }

        return isSearching ? "Search results" : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "JobTypeCellIdentifier",
            for: indexPath
        )

        var content = cell.defaultContentConfiguration()

        if indexPath.section == 0 {
            // Saved job types with red minus icon
            content.text = savedJobTypes[indexPath.row]
            content.image = UIImage(systemName: "minus.circle")
            content.imageProperties.tintColor = .systemRed

        } else {
            // Search results with green plus icon
            content.text = filteredJobTypes[indexPath.row]
            content.image = UIImage(systemName: "plus.circle")
            content.imageProperties.tintColor = UIColor(named: "DarkGreen")
        }

        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Remove or add depending on what part of table is clicked
        if indexPath.section == 0 {
            removeJobType(at: indexPath.row)
            return
        }
        let jobType = filteredJobTypes[indexPath.row]
        addJobType(jobType)
    }
}
