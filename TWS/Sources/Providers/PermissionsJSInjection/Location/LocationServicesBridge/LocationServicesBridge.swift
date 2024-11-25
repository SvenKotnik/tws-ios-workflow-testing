//
//  LocationServicesBridge.swift
//  TWSAPI
//
//  Created by Miha Hozjan on 28. 8. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation
import CoreLocation

/// A protocol defining a service interface for location-related interactions.
///
/// This interface facilitates communication between the JavaScript environment and the iOS environment, handling location permissions, retrieving the current position, and managing continuous location updates.
///
/// > Note: By default, a location services manager is provided. You can supply your own implementation by using the ``SwiftUICore/View/twsBind(locationServiceBridge:)`` helper function.
public protocol LocationServicesBridge: Actor {

    /// Checks if location permissions are granted.
    ///
    /// Before calling `getCurrentPosition` or `watchPosition`, this method verifies whether the necessary permissions are in place.
    /// If permissions are not granted, it notifies the JavaScript environment.
    ///
    /// - Throws: An error if the user denies or restricts access to location services.
    func checkPermission() async throws

    /// Retrieves the most recent known location.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the location update session.
    ///   - options: An optional instance of ``JSLocationMessageOptions`` specifying options such as maximum age, timeout, and accuracy for the location updates.
    /// - Returns: The last known location, or `nil` if no location data is available.
    func location(
        id: Double,
        options: JSLocationMessageOptions?
    ) async -> CLLocation?

    /// Starts continuous location updates.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the location update session.
    ///   - options: An optional instance of `JSLocationMessageOptions` specifying options such as maximum age, timeout, and accuracy for the location updates.
    /// - Returns: An `AsyncStream` that yields `CLLocation` objects as the device's location updates.
    func startUpdatingLocation(
        id: Double,
        options: JSLocationMessageOptions?
    ) -> AsyncStream<CLLocation>

    /// Stops continuous location updates for the specified session ID.
    ///
    /// - Parameter id: The unique identifier for the location update session to be stopped.
    func stopUpdatingLocation(id: Double)
}
