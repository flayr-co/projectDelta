//
//  Views+Extensions.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/14/23.
//

import Foundation
import SwiftUI

extension View {
    func embedInNavigationView() -> some View {
        NavigationView { self }
    }
}
