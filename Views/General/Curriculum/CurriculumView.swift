//
//  CurriculumView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI

let heightPerClass = 60.0
let paddingWidth = 2.0

struct CurriculumView: View {
    @AppStorage("curriculumShowSatAndSun") var showSatAndSun = false
    @AppStorage("semesterID") var semesterID = "281"
    @State var courses: [Course] = []
    @State var status: AsyncViewStatus = .inProgress
    @State var showSettingSheet = false
    @State var saveCalendarStatus: AsyncViewStatus = .inProgress
    var settingSheet: some View {
        NavigationStack {
            List {
                Toggle(isOn: $showSatAndSun) {
                    Label("Sat&Sun", systemImage: "lines.measurement.horizontal")
                }

                // Notice that this is only achieving a Picker's functionality, but perhaps writing the code this way is much more simpler
                HStack {
                    Label("Select time", systemImage: "square.3.stack.3d")
                    Spacer()
                    Menu {
                        ForEach(UstcUgAASClient.semesterIDList.sorted(by: { $0.value < $1.value }), id: \.key) { key, id in
                            Button {
                                semesterID = id
                                UstcUgAASClient.main.semesterID = semesterID
                                asyncBind($courses, status: $status) {
                                    try await UstcUgAASClient.main.forceUpdateCurriculum()
                                    return try await UstcUgAASClient.main.getCurriculum()
                                }
                            } label: {
                                if semesterID == id {
                                    HStack {
                                        Text(key)
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                Text(key)
                            }
                        }
                    } label: {
                        Text(UstcUgAASClient.semesterIDList.first(where: { $0.value == semesterID })?.key ?? "")
                    }
                }

                Button {
                    withAnimation {
                        asyncBind(.constant(()), status: $saveCalendarStatus) {
                            try UstcUgAASClient.main.saveToCalendar()
                        }
#if os(iOS)
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
#endif
                        Task {
                            try await Task.sleep(for: .seconds(2))
                            saveCalendarStatus = .inProgress
                        }
                    }
                } label: {
                    HStack {
                        Label("Save to Calendar", systemImage: "square.and.arrow.down")
                        Spacer()
                        switch saveCalendarStatus {
                        case .success:
                            HStack {
                                Text("Saved")
                                Image(systemName: "checkmark.seal")
                            }
                            .foregroundColor(.accentColor)
                        case .inProgress:
                            EmptyView()
                        case .failure:
                            HStack {
                                Text("Something Went Wrong")
                                Image(systemName: "questionmark.diamond.fill")
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .navigationBarTitle("Settings", displayMode: .inline)
        }
        .presentationDetents([.fraction(0.4)])
    }

    var body: some View {
        NavigationStack {
            mainView
                .padding(paddingWidth)
                .toolbar {
                    if status == .inProgress {
                        ProgressView()
                    }
                    Button {
                        withAnimation {
                            showSettingSheet.toggle()
                        }
                    } label: {
                        Label("Show settings", systemImage: "gearshape")
                    }
                }
                .navigationBarTitle("Curriculum", displayMode: .inline)
                .onAppear {
                    asyncBind($courses, status: $status) {
                        try await UstcUgAASClient.main.getCurriculum()
                    }
                }
                .sheet(isPresented: $showSettingSheet) {
                    settingSheet
                }
        }
    }

    func makeVStack(index: Int) -> some View {
        VStack {
            Text(daysOfWeek[index])
            ZStack(alignment: .top) {
                Color.clear

                ForEach(courses) { course in
                    if course.dayOfWeek == (index + 1) {
                        CourseCardView(course: course)
                            .offset(y: Double(course.startTime - 1) * heightPerClass)
                    }
                }

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.accentColor)
                    .offset(y: 5 * heightPerClass)
                    .opacity(0.5)

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.accentColor)
                    .offset(y: 10 * heightPerClass)
                    .opacity(0.5)
            }
        }
    }

    var loadedView: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(0 ..< 5) { index in
                            makeVStack(index: index)
                                .frame(width: geo.size.width / 5, height: heightPerClass * 13)
                        }
                        if showSatAndSun {
                            ForEach(5 ..< 7) { index in
                                makeVStack(index: index)
                                    .frame(width: geo.size.width / 5, height: heightPerClass * 13)
                            }
                        }
                    }
                }
                .scrollDisabled(!showSatAndSun)
            }
        }
    }

    var mainView: some View {
        Group {
            if status == .inProgress {
                ProgressView()
            } else {
                loadedView
            }
        }
    }
}

struct CurriculumView_Previews: PreviewProvider {
    static var previews: some View {
        CurriculumView()
    }
}
