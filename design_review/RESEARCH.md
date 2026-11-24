# ARTICKET 디자인 리서치 03

이번 검토안은 승인한 05 AT 로고와 오프화이트·차콜·절제된 코랄을 공통으로 사용합니다.
색을 크게 바꾸기보다, 기록을 찾는 기준과 이미지·글·티켓·컬렉션의 우선순위를 다르게 구성했습니다.

| 시안 | 기록을 보는 기준 | 참고한 구성 원리 |
|---|---|---|
| 01 작품 그리드 | 작품 썸네일 → 컬렉션 | 아트 갤러리의 일정한 그리드, 짧은 메타데이터와 작은 액션 |
| 02 한 장의 전시 | 이미지 한 장 → 짧은 관람 일지 | 저널의 읽는 순서와 사진·문장 사이 여백 |
| 03 티켓 포켓 | 수집한 티켓 → 상세 기록 | 사진 저널의 겹쳐진 인화지, 티켓을 모으는 감각 |
| 04 관람 타임라인 | 관람일 → 장소·평가·기록 | 날짜별 엔트리와 반복되는 리스트 정보 위계 |
| 05 컬렉션 서가 | 컬렉션 → 그 안의 티켓 | 앨범·컬렉션을 먼저 고르는 탐색 구조 |

## 직접 확인한 공개 레퍼런스

- [Envato — Art Gallery App UI Kit / betush](https://elements.envato.com/art-gallery-app-ui-kit-85E5E2Z): 작품 그리드, 썸네일 비중, 얇은 내비게이션과 짧은 캡션.
- [Envato — Online Museum & Art Gallery / uicube](https://elements.envato.com/online-museum-art-gallery-mobile-app-ui-kit-EZ4U3MP): 이미지 중심 리스트와 카드, 정보가 많은 화면에서의 정렬과 밀도.
- [Envato — Diary App–Jurnal / burdurstudio](https://elements.envato.com/diary-app-jurnal-mobile-app-ui-kit-EQ3GSL2): 날짜별 엔트리, 짧은 글의 읽는 순서, 입력 화면의 일관성.
- [Dribbble — relive / Luca Canu](https://dribbble.com/shots/24595032-relive-Mobile-App-Design-Concept): 사진을 다시 꺼내보는 기억 중심 구성과 앨범의 시각적 그룹핑.
- [Dribbble — Art Gallery mobile app UI / Natalie](https://dribbble.com/shots/14739721-Art-Gallery-mobile-app-UI): 이미지·제목·메타데이터의 간결한 정보 구조.

유료 템플릿 원본·사진·타사 브랜드는 복제하거나 포함하지 않았습니다. 공개 미리보기를 조사하고 ARTICKET의 개인 관람 기록 기능에 맞춰 새로 구성했습니다.

## 실제 렌더링과 범위

모든 앱 화면은 실제 Flutter 위젯, 저장소의 한글 폰트와 원본 벡터 AT 로고로 렌더링했습니다.
개별 화면 25개, 시안별 비교 보드 5개, 홈 비교 보드 1개를 포함합니다.
색은 배경 `#FAF9F6`~`#F5F3ED`, 글자 `#292C29`, 포인트 `#B56858` 범위로 제한했습니다.

이 자료는 디자인 검토안입니다. 클릭 동작·운영 데이터와 연결하지 않았으며 앱 main의 UI에 적용하지 않았습니다.
작품 사진 출처는 ARTWORK_CREDITS.txt를 확인하세요. 화면의 관람일·장소·전시 제목은 비교용 예시입니다.
