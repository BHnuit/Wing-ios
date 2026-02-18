//
//  StatisticsView.swift
//  Wing
//
//  Created on 2026-02-18.
//

import SwiftUI

struct StatisticsView: View {
    let daysRecorded: Int
    let todayFlaps: Int
    let totalFeathers: Int
    
    var body: some View {
        HStack(spacing: 16) {
            statItem(
                value: daysRecorded,
                unit: L("stats.unit.days"),
                label: L("settings.stats.label.totalDays")
            )
            
            Divider()
            
            statItem(
                value: todayFlaps,
                unit: L("stats.unit.times"),
                label: L("settings.stats.label.todayFlaps")
            )
            
            Divider()
            
            statItem(
                value: totalFeathers,
                unit: L("stats.unit.feathers"),
                label: L("settings.stats.label.totalFeathers")
            )
        }
        .padding(.vertical, 8)
    }
    
    private func statItem(value: Int, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                    .minimumScaleFactor(0.5)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    List {
        Section {
            StatisticsView(daysRecorded: 3, todayFlaps: 2, totalFeathers: 139)
        } header: {
            Text("Overview")
        }
    }
    .listStyle(.insetGrouped)
}
