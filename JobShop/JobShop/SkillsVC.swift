//
//  SkillsVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 11/4/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SkillsVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var errorMessage: UILabel!

    let db = Firestore.firestore()

    var allSkills = [String]()
    var filteredSkills = [String]()
    var savedSkills = [String]()
    var originalSkills = [String]()

    var isSearching: Bool {
        return !(searchBar.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self

        errorMessage.text = ""

        allSkills = loadSkills()
        filteredSkills = allSkills

        loadSavedSkills()
    }

    @IBAction func savePressed(_ sender: Any) {
        errorMessage.text = ""

        guard let user = Auth.auth().currentUser else {
            errorMessage.text = "Error saving skills."
            return
        }

        db.collection("accounts").document(user.uid)
            .setData(["skills": savedSkills], merge: true) { [weak self] err in

                guard let self = self else { return }

                if let err = err {
                    self.errorMessage.text = err.localizedDescription
                } else {
                    self.originalSkills = self.savedSkills
                    self.dismiss(animated: true)
                }
            }
    }

    @IBAction func cancelPressed(_ sender: Any) {
        savedSkills = originalSkills
        dismiss(animated: true)
    }

    func loadSkills() -> [String] {
        return loadCSV(fileName: "skills")
    }

    // function for reading a CSV file
    func loadCSV(fileName: String) -> [String] {
        guard let url = Bundle.main.url(
            forResource: fileName,
            withExtension: "csv"
        ) else {
            print("Unable to find \(fileName).csv")
            return []
        }

        guard let data = try? String(contentsOf: url, encoding: .utf8) else {
            print("Unable to read \(fileName).csv")
            return []
        }

        let values = data.components(separatedBy: .newlines)

        let cleanedValues = values.compactMap { value -> String? in
            let name = value.trimmingCharacters(in: .whitespacesAndNewlines)

            if name.isEmpty {
                return nil
            }

            return name
        }

        // Remove duplicates and alphabetize
        return Array(Set(cleanedValues)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func loadSavedSkills() {
        guard let user = Auth.auth().currentUser else {
            errorMessage.text = "Unable to load skills."
            return
        }

        db.collection("accounts").document(user.uid).getDocument { [weak self] document, err in

            guard let self = self else { return }

            if let err = err {
                self.errorMessage.text = err.localizedDescription
                return
            }

            if let data = document?.data() {
                self.savedSkills = data["skills"] as? [String] ?? []
            } else {
                self.savedSkills = []
            }

            self.originalSkills = self.savedSkills
            self.tableView.reloadData()
        }
    }

    func addSkill(_ name: String) {
        errorMessage.text = ""

        if savedSkills.contains(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) {
            return
        }

        savedSkills.append(name)

        searchBar.text = ""
        searchBar.resignFirstResponder()

        filteredSkills = allSkills
        tableView.reloadData()
    }

    func removeSkill(at index: Int) {
        errorMessage.text = ""

        savedSkills.remove(at: index)
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filteredSkills = allSkills
        } else {
            filteredSkills = allSkills.filter { skill in
                skill.localizedCaseInsensitiveContains(searchText) &&
                !savedSkills.contains(where: {
                    $0.caseInsensitiveCompare(skill) == .orderedSame
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
            return savedSkills.count
        }

        return isSearching ? filteredSkills.count : 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return savedSkills.isEmpty ? "No skills added yet" : "Your skills"
        }

        return isSearching ? "Search results" : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "SkillCellIdentifier",
            for: indexPath
        )

        var content = cell.defaultContentConfiguration()

        if indexPath.section == 0 {
            // Saved skills with red minus icon
            content.text = savedSkills[indexPath.row]
            content.image = UIImage(systemName: "minus.circle")
            content.imageProperties.tintColor = .systemRed

        } else {
            // Search results with green plus icon
            content.text = filteredSkills[indexPath.row]
            content.image = UIImage(systemName: "plus.circle")
            content.imageProperties.tintColor = UIColor(named: "DarkGreen")
        }

        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Remove or add skill depending on what part of table is clicked
        if indexPath.section == 0 {
            removeSkill(at: indexPath.row)
            return
        }
        let skill = filteredSkills[indexPath.row]
        addSkill(skill)
    }
}

