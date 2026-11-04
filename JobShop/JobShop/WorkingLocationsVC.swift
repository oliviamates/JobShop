//
//  WorkingLocationsVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 11/2/26.
//


import UIKit
import MapKit
import FirebaseAuth
import FirebaseFirestore

class WorkingLocationsVC: UIViewController, UITableViewDelegate, UITableViewDataSource,
                          UISearchBarDelegate, MKLocalSearchCompleterDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var errorMessage: UILabel!
    
    let db = Firestore.firestore()
    let completer = MKLocalSearchCompleter()

    var results = [MKLocalSearchCompletion]()
    var savedLocations = [String]()
    var originalLocations = [String]()

    var isSearching: Bool {
        return !(searchBar.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        completer.delegate = self
        completer.resultTypes = .address
        errorMessage.text = ""
        loadSavedLocations()
    }
    
    @IBAction func savePressed(_ sender: Any) {
        errorMessage.text = ""
        if let user = Auth.auth().currentUser {
            db.collection("accounts").document(user.uid)
                .setData(["workingLocations": savedLocations], merge: true) { err in
                    if let err = err {
                        self.errorMessage.text = "\(err.localizedDescription)"
                    } else {
                        self.originalLocations = self.savedLocations
                        self.dismiss(animated: true)
                    }
                }
        } else {
            self.errorMessage.text = "Error saving working locations."
        }
    }
    
    
    @IBAction func cancelPressed(_ sender: Any) {
        savedLocations = originalLocations
        dismiss(animated: true)
    }
    
    // load previously saved working locations
    func loadSavedLocations() {
        if let user = Auth.auth().currentUser {
            db.collection("accounts").document(user.uid).getDocument { document, err in
                if let err = err {
                    self.errorMessage.text = "\(err.localizedDescription)"
                } else if let data = document?.data() {
                    self.savedLocations = data["workingLocations"] as? [String] ?? []
                    self.originalLocations = self.savedLocations
                } else {
                    self.savedLocations = []
                    self.originalLocations = []
                }
                self.tableView.reloadData()
            }
        }
    }

    // Add a new working location
    func addLocation(_ name: String) {
        errorMessage.text = ""
        if savedLocations.contains(name) {
            // if location is already in list
            return
        }
        savedLocations.append(name)
        searchBar.text = ""
        searchBar.resignFirstResponder()
        results = []
        tableView.reloadData()
    }

    // Remove a working location
    func removeLocation(at index: Int) {
        errorMessage.text = ""
        savedLocations.remove(at: index)
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            results = []
            tableView.reloadData()
        } else {
            completer.queryFragment = searchText
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results.filter { result in
            !result.title.contains(where: { $0.isNumber })
        }

        tableView.reloadData()
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search error: \(error.localizedDescription)")
    }

    // two sections: saved locations and search results
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return savedLocations.count
        }

        return isSearching ? results.count : 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return savedLocations.isEmpty ? "No working locations added yet" : "Your working locations"
        }

        return isSearching ? "Search results" : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "LocationCellIdentifier",
            for: indexPath
        )

        var content = cell.defaultContentConfiguration()

        if indexPath.section == 0 {
            // Saved locations with red minus icon
            content.text = savedLocations[indexPath.row]
            content.image = UIImage(systemName: "minus.circle")
            content.imageProperties.tintColor = .systemRed

        } else {
            // Search suggestion with green plus icon
            content.text = results[indexPath.row].title
            content.secondaryText = results[indexPath.row].subtitle
            content.image = UIImage(systemName: "plus.circle")
            content.imageProperties.tintColor = UIColor(named: "DarkGreen")
        }

        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: true)

        // Tapping a saved location removes it
        if indexPath.section == 0 {
            removeLocation(at: indexPath.row)
            return
        }

        // Tapping a search result adds it
        let completion = results[indexPath.row]
        let request = MKLocalSearch.Request(completion: completion)

        MKLocalSearch(request: request).start { response, error in

            if let err = error {
                self.errorMessage.text = "\(err.localizedDescription)"
                return
            }

            let placemark = response?.mapItems.first?.placemark

            let city = placemark?.locality ?? completion.title
            let state = placemark?.administrativeArea ?? ""

            let location = state.isEmpty ? city : "\(city), \(state)"

            self.addLocation(location)
        }
    }
}

