//
//  QuoteListView.swift
//  news
//
//  명언 전체 목록 조회 화면
//

import SwiftUI

// MARK: - Quote List View
struct QuoteListView: View {
    @Environment(\.dismiss) var dismiss
    let quotes: [BibleVerse]
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    
    // 검색 및 필터링된 명언
    private var filteredQuotes: [BibleVerse] {
        var result = quotes
        
        // 카테고리 필터
        if let category = selectedCategory {
            result = result.filter { $0.themes.contains(category) }
        }
        
        // 검색어 필터
        if !searchText.isEmpty {
            result = result.filter { quote in
                quote.krv.localizedCaseInsensitiveContains(searchText) ||
                quote.reference.localizedCaseInsensitiveContains(searchText) ||
                quote.themes.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return result
    }
    
    // 모든 카테고리 추출
    private var allCategories: [String] {
        let categories = quotes.flatMap { $0.themes }
        return Array(Set(categories)).sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 검색 바
                searchBar
                
                // 카테고리 필터
                if !allCategories.isEmpty {
                    categoryFilterBar
                }
                
                // 명언 리스트
                if filteredQuotes.isEmpty {
                    emptyStateView
                } else {
                    quoteList
                }
            }
            .navigationTitle("명언 모음")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedCategory != nil || !searchText.isEmpty {
                        Button("초기화") {
                            withAnimation {
                                selectedCategory = nil
                                searchText = ""
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("명언, 출처, 카테고리 검색...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Category Filter Bar
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allCategories, id: \.self) { category in
                    Button(action: {
                        withAnimation {
                            if selectedCategory == category {
                                selectedCategory = nil
                            } else {
                                selectedCategory = category
                            }
                        }
                    }) {
                        Text(category)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == category ?
                                Color.blue : Color(UIColor.tertiarySystemGroupedBackground)
                            )
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Quote List
    private var quoteList: some View {
        List {
            Section {
                ForEach(filteredQuotes) { quote in
                    QuoteRowView(quote: quote)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            } header: {
                HStack {
                    Text("\(filteredQuotes.count)개의 명언")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("검색 결과가 없습니다")
                .font(.headline)
            
            Text("다른 키워드로 검색해보세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Quote Row View
struct QuoteRowView: View {
    let quote: BibleVerse
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 명언 내용
            Text(quote.krv)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut, value: isExpanded)
            
            // 출처 및 카테고리
            HStack {
                Text(quote.reference)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                Spacer()
                
                // 카테고리 태그
                HStack(spacing: 4) {
                    ForEach(quote.themes.prefix(4), id: \.self) { theme in
                        Text(theme)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    if quote.themes.count > 4 {
                        Text("+\(quote.themes.count - 4)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 펼치기/접기 버튼 (3줄 이상인 경우)
            if needsExpansion(text: quote.krv) {
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Text(isExpanded ? "접기" : "더보기")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if needsExpansion(text: quote.krv) {
                withAnimation {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    private func needsExpansion(text: String) -> Bool {
        // 간단한 휴리스틱: 50자 이상이면 펼치기 버튼 표시
        return text.count > 50
    }
}

// MARK: - Preview
struct QuoteListView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleQuotes = [
            BibleVerse(
                id: 1,
                reference: "잠언 21:5",
                krv: "부지런한 자의 경영은 풍부함에 이르거니와",
                niv: "The plans of the diligent lead to profit.",
                themes: ["계획", "부지런함"]
            ),
            BibleVerse(
                id: 2,
                reference: "고린도전서 9:27",
                krv: "내 몸을 쳐 복종하게 함은",
                niv: "I discipline my body and keep it under control.",
                themes: ["절제", "자기관리"]
            ),
            BibleVerse(
                id: 3,
                reference: "아리스토텔레스",
                krv: "우리는 반복적으로 하는 행동의 결과입니다. 따라서 탁월함은 행동이 아니라 습관입니다.",
                niv: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.",
                themes: ["습관", "탁월함"]
            )
        ]
        
        QuoteListView(quotes: sampleQuotes)
    }
}

