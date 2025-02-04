//
//  USTC+ClassroomDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/18.
//

import SwiftUI
import SwiftyJSON

func loadBuildingInfo() -> [String: [String]] {
    let path = Bundle.main.path(forResource: "ustc_rooms", ofType: "json")!
    let data = try! Data(
        contentsOf: URL(fileURLWithPath: path),
        options: .mappedIfSafe
    )
    let cache = try! JSON(data: data)

    var result: [String: [String]] = [:]

    for (_, subJson) in cache {
        let building = subJson["buildingCode"].stringValue
        let room = subJson["code"].stringValue

        if result.keys.contains(building) {
            result[building]?.append(room)
        } else {
            result[building] = [room]
        }
    }
    return result
}

let ustcBuildingRooms: [String: [String]] = loadBuildingInfo()
let ustcBuildingNames: [String: String] = [
    "1": "第一教学楼",
    "2": "第二教学楼",
    "3": "第三教学楼",
    "5": "第五教学楼",
    "17": "先研院未来中心",
    "11": "高新校区图书教育中心A楼",
    "12": "高新校区图书教育中心B楼",
    "13": "高新校区图书教育中心C楼",
    "14": "高新校区师生活动中心",
    "22": "高新校区信智楼",
]

class USTCClassroomDelegate: ManagedRemoteUpdateProtocol<[String: [Lecture]]> {
    static let shared = USTCClassroomDelegate()

    @LoginClient(.ustcCatalog) var catalogClient: UstcCatalogClient
    @AppStorage("ustcClassroomSelectedDate") var date: Date = .now

    var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: date)
    }

    func parseDate(_ time: String) -> Date {
        // time format: hh:mm, add that to date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let date = dateFormatter.date(from: "\(dateString) \(time)")!
        return date
    }

    override func refresh() async throws -> [String: [Lecture]] {
        if try await !_catalogClient.requireLogin() {
            throw BaseError.runtimeError("UstcCatalog Not logined")
        }
        let validToken = catalogClient.token

        var cache: [String: JSON] = [:]
        for building in ustcBuildingNames.keys {
            let url = URL(
                string:
                    "https://catalog.ustc.edu.cn/api/teach/timetable-public/\(building)/\(dateString)?access_token=\(validToken)"
            )!
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            cache[building] = try JSON(data: data)
        }

        var result: [String: [Lecture]] = [:]
        for building in ustcBuildingNames.keys {
            result[building] = []
            if let json = cache[building] {
                for (_, subJson) in json["timetable"]["lessons"] {
                    let tmp = Lecture(
                        startDate: parseDate(subJson["start"].stringValue),
                        endDate: parseDate(subJson["end"].stringValue),
                        name: subJson["courseName"].stringValue,
                        location: subJson["classroomName"].stringValue,
                        additionalInfo: ["Color": "blue"]
                    )
                    result[building]?.append(tmp)
                }

                for (_, subJson) in json["timetable"]["tmpLessons"] {
                    let tmp = Lecture(
                        startDate: parseDate(subJson["start"].stringValue),
                        endDate: parseDate(subJson["end"].stringValue),
                        name: subJson["courseName"].stringValue,
                        location: subJson["classroomName"].stringValue,
                        additionalInfo: ["Color": "green"]
                    )
                    result[building]?.append(tmp)
                }

                for (_, subJson) in json["timetable"]["exams"] {
                    let tmp = Lecture(
                        startDate: parseDate(subJson["start"].stringValue),
                        endDate: parseDate(subJson["end"].stringValue),
                        name: subJson["lessons"][0]["nameZh"].stringValue,
                        location: subJson["classroomName"].stringValue,
                        additionalInfo: ["Color": "green"]
                    )
                    result[building]?.append(tmp)
                }
            }
        }
        return result
    }
}

extension [String: [Lecture]]: ExampleDataProtocol {
    static let example: [String: [Lecture]] = ["2": [.example]]
}

extension ManagedDataSource<[String: [Lecture]]> {
    static let classroom = ManagedDataSource(
        local: ManagedLocalStorage("ustc_classroom"),
        remote: USTCClassroomDelegate.shared
    )
}
