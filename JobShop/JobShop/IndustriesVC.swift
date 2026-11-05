//
//  IndustriesVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 11/4/26.
//


import UIKit
import FirebaseAuth
import FirebaseFirestore

class IndustriesVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var errorMessage: UILabel!

    let db = Firestore.firestore()

    var allIndustries = [String]()
    var filteredIndustries = [String]()
    var savedIndustries = [String]()
    var originalIndustries = [String]()

    var isSearching: Bool {
        return !(searchBar.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self

        errorMessage.text = ""

        allIndustries = loadIndustries()
        filteredIndustries = allIndustries

        loadSavedIndustries()
    }

    @IBAction func savePressed(_ sender: Any) {
        errorMessage.text = ""

        guard let user = Auth.auth().currentUser else {
            errorMessage.text = "Error saving industries."
            return
        }

        db.collection("accounts").document(user.uid)
            .setData(["industries": savedIndustries], merge: true) { [weak self] err in

                guard let self = self else { return }

                if let err = err {
                    self.errorMessage.text = err.localizedDescription
                } else {
                    self.originalIndustries = self.savedIndustries
                    self.dismiss(animated: true)
                }
            }
    }

    @IBAction func cancelPressed(_ sender: Any) {
        savedIndustries = originalIndustries
        dismiss(animated: true)
    }

    func loadIndustries() -> [String] {
        return loadCSV(fileName: "industries")
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

    func loadSavedIndustries() {
        guard let user = Auth.auth().currentUser else {
            errorMessage.text = "Unable to load industries."
            return
        }

        db.collection("accounts").document(user.uid).getDocument { [weak self] document, err in

            guard let self = self else { return }

            if let err = err {
                self.errorMessage.text = err.localizedDescription
                return
            }

            if let data = document?.data() {
                self.savedIndustries = data["industries"] as? [String] ?? []
            } else {
                self.savedIndustries = []
            }

            self.originalIndustries = self.savedIndustries
            self.tableView.reloadData()
        }
    }

    func addIndustry(_ name: String) {
        errorMessage.text = ""

        if savedIndustries.contains(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) {
            return
        }

        savedIndustries.append(name)

        searchBar.text = ""
        searchBar.resignFirstResponder()

        filteredIndustries = allIndustries
        tableView.reloadData()
    }

    func removeIndustry(at index: Int) {
        errorMessage.text = ""

        savedIndustries.remove(at: index)
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filteredIndustries = allIndustries
        } else {
            filteredIndustries = allIndustries.filter { industry in
                industry.localizedCaseInsensitiveContains(searchText) &&
                !savedIndustries.contains(where: {
                    $0.caseInsensitiveCompare(industry) == .orderedSame
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
            return savedIndustries.count
        }

        return isSearching ? filteredIndustries.count : 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return savedIndustries.isEmpty ? "No industries added yet" : "Your industries"
        }

        return isSearching ? "Search results" : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "IndustryCellIdentifier",
            for: indexPath
        )

        var content = cell.defaultContentConfiguration()

        if indexPath.section == 0 {
            // Saved industries with red minus icon
            content.text = savedIndustries[indexPath.row]
            content.image = UIImage(systemName: "minus.circle")
            content.imageProperties.tintColor = .systemRed

        } else {
            // Search results with green plus icon
            content.text = filteredIndustries[indexPath.row]
            content.image = UIImage(systemName: "plus.circle")
            content.imageProperties.tintColor = UIColor(named: "DarkGreen")
        }

        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Remove or add industry depending on what part of table is clicked
        if indexPath.section == 0 {
            removeIndustry(at: indexPath.row)
            return
        }
        let industry = filteredIndustries[indexPath.row]
        addIndustry(industry)
    }
}
