import Foundation
import CoreLocation
import SwiftSignalKit

func geocodeLocation(dictionary: [String: String]) -> Signal<(Double, Double)?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressDictionary(dictionary, completionHandler: { placemarks, _ in
            if let location = placemarks?.first?.location {
                subscriber.putNext((location.coordinate.latitude, location.coordinate.longitude))
            } else {
                subscriber.putNext(nil)
            }
            subscriber.putCompletion()
        })
        return ActionDisposable {
            geocoder.cancelGeocode()
        }
    }
}

struct ReverseGeocodedPlacemark {
    let street: String?
    let city: String?
    let country: String?
    
    var fullAddress: String {
        var components: [String] = []
        if let street = self.street {
            components.append(street)
        }
        if let city = self.city {
            components.append(city)
        }
        if let country = self.country {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
}

func reverseGeocodeLocation(latitude: Double, longitude: Double) -> Signal<ReverseGeocodedPlacemark?, NoError> {
    return Signal { subscriber in
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude), completionHandler: { placemarks, _ in
            if let placemarks = placemarks, let placemark = placemarks.first {
                let result = ReverseGeocodedPlacemark(street: placemark.thoroughfare, city: placemark.locality, country: placemark.country)
                subscriber.putNext(result)
                subscriber.putCompletion()
            } else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
        })
        return ActionDisposable {
            geocoder.cancelGeocode()
        }
    }
}
