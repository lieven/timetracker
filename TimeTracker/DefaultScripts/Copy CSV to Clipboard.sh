#!/usr/bin/env xcrun swift

import Foundation

var allData = Data()
while let line = readLine(strippingNewline: false) {
	guard let lineData = line.data(using: .utf8) else {
		print("Unreadable data\n")
		exit(1)
	}
	allData.append(lineData)
}

print("Read \(allData.count) bytes\n")


guard let projects = try? JSONSerialization.jsonObject(with: allData) as? [[String: Any]] else {
	print("Expected array\n")
	exit(1)
}

for project in projects {
	if let tasks = project["tasks"] as? [[String: Any]] {
		for task in tasks {
			if let taskName = task["name"] as? String, let taskDuration = task["duration"] as? TimeInterval {
				let durationHours = Int(taskDuration / 3600.0)
				let remainingSeconds = taskDuration - 3600.0 * Double(durationHours)
				let durationMinutes = Int(round(remainingSeconds / 60.0))
				
				print("\(taskName)\t\(String(format: "%02d:%02d", durationHours, durationMinutes))\n")
			}
		}
	}
}
