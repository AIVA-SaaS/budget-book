class CardIssuerPreset {
  final String id;
  final String name;
  final int settlementDay;
  final int closingDay;
  final String description;

  const CardIssuerPreset({
    required this.id,
    required this.name,
    required this.settlementDay,
    required this.closingDay,
    required this.description,
  });
}

const cardIssuerPresets = [
  CardIssuerPreset(
    id: 'shinhan',
    name: '신한카드',
    settlementDay: 14,
    closingDay: 15,
    description: '전월 16일 ~ 당월 15일',
  ),
  CardIssuerPreset(
    id: 'kb',
    name: 'KB국민카드',
    settlementDay: 14,
    closingDay: 14,
    description: '전월 15일 ~ 당월 14일',
  ),
  CardIssuerPreset(
    id: 'samsung',
    name: '삼성카드',
    settlementDay: 12,
    closingDay: 12,
    description: '전월 13일 ~ 당월 12일',
  ),
  CardIssuerPreset(
    id: 'hyundai',
    name: '현대카드',
    settlementDay: 17,
    closingDay: 31,
    description: '1일 ~ 말일',
  ),
  CardIssuerPreset(
    id: 'lotte',
    name: '롯데카드',
    settlementDay: 16,
    closingDay: 31,
    description: '1일 ~ 말일',
  ),
  CardIssuerPreset(
    id: 'hana',
    name: '하나카드',
    settlementDay: 10,
    closingDay: 10,
    description: '전월 11일 ~ 당월 10일',
  ),
  CardIssuerPreset(
    id: 'woori',
    name: '우리카드',
    settlementDay: 14,
    closingDay: 14,
    description: '전월 15일 ~ 당월 14일',
  ),
  CardIssuerPreset(
    id: 'nh',
    name: 'NH농협카드',
    settlementDay: 14,
    closingDay: 14,
    description: '전월 15일 ~ 당월 14일',
  ),
  CardIssuerPreset(
    id: 'bc',
    name: 'BC카드',
    settlementDay: 12,
    closingDay: 11,
    description: '전월 12일 ~ 당월 11일',
  ),
  CardIssuerPreset(
    id: 'kakao',
    name: '카카오뱅크',
    settlementDay: 14,
    closingDay: 15,
    description: '전월 16일 ~ 당월 15일',
  ),
  CardIssuerPreset(
    id: 'toss',
    name: '토스뱅크',
    settlementDay: 15,
    closingDay: 15,
    description: '전월 16일 ~ 당월 15일',
  ),
];
