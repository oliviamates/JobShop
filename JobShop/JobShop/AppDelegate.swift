//
//  AppDelegate.swift
//  JobShop
//
//  Created by Olivia Mates on 10/12/26.
//

import UIKit
import FirebaseCore
import UserNotifications
import FirebaseAppCheck
import CoreLocation
import MapKit

var currCity:String = ""
var currState:String = ""
@main

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, CLLocationManagerDelegate {

    let locationManager = CLLocationManager()
    var isLocating = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        FirebaseApp.configure()
        locationManager.delegate = self
        checkLocationAuthorization()
//        locationManager.startUpdatingLocation()

    
        return true
    }
    func checkLocationAuthorization() {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .restricted, .denied:
                print("Location access denied. Please enable it in Settings.")
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            @unknown default:
                break
            }
        }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        // prevents multiple location requests at the same time
        if isLocating {
            return
        }

        guard let location = locations.last else { return }
        isLocating = true

        Task {
            defer {
                isLocating = false
            }

            guard let request = MKReverseGeocodingRequest(location: location) else {
                return
            }

            do {
                let mapItems = try await request.mapItems

                if let firstItem = mapItems.first,
                   let city = firstItem.addressRepresentations?.cityName,
                   let state = firstItem.addressRepresentations?.regionName {
                    print("Current City via MapKit: \(city)")
                    currCity = city
                    currState = state
                }

            } catch {
                print("MapKit reverse geocoding failed: \(error.localizedDescription)")
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
            let token = tokenParts.joined()
            print("Device Token: \(token)")
        }

        func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
            print("Failed to register: \(error)")
        }


    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}

