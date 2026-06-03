import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/report.dart';

class ReportPalette {
  static const navy = AppColors.reportNavy;
  static const navyDeep = AppColors.reportNavyDeep;
  static const navySoft = AppColors.reportNavySoft;
  static const surface = AppColors.reportSurface;
  static const card = AppColors.reportSurfaceCard;
  static const raised = AppColors.reportSurfaceRaised;
  static const overlay = AppColors.reportSurfaceOverlay;
  static const ink = AppColors.reportInk;
  static const inkSecondary = AppColors.reportInkSecondary;
  static const inkTertiary = AppColors.reportInkTertiary;
  static const hairline = AppColors.reportHairline;
  static const hairlineSoft = AppColors.reportHairlineSoft;
  static const hairlineStrong = AppColors.reportHairlineStrong;
  static const verified = AppColors.reportVerified;
  static const verifiedSoft = AppColors.reportVerifiedSoft;
  static const disputed = AppColors.reportDisputed;
}

class ReportTextStyles {
  static const h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: ReportPalette.ink,
    height: 1.15,
  );
  static const subtitle = TextStyle(
    fontSize: 13,
    color: ReportPalette.inkTertiary,
    height: 1.45,
  );
  static const sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: ReportPalette.inkTertiary,
  );
  static const body = TextStyle(
    fontSize: 14,
    color: ReportPalette.inkSecondary,
    height: 1.55,
  );
  static const micro = TextStyle(
    fontSize: 11,
    color: ReportPalette.inkTertiary,
    height: 1.4,
  );
  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    color: ReportPalette.ink,
    letterSpacing: 0.5,
  );
}

class ReportCategoryStyle {
  final ReportCategory category;
  final String label;
  final IconData icon;
  final Color color;
  const ReportCategoryStyle({
    required this.category,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const reportCategoryStyles = <ReportCategoryStyle>[
  ReportCategoryStyle(
    category: ReportCategory.combat,
    label: 'Combat / strike',
    icon: Icons.crisis_alert,
    color: AppColors.reportCatCombat,
  ),
  ReportCategoryStyle(
    category: ReportCategory.aid,
    label: 'Humanitarian aid',
    icon: Icons.favorite,
    color: AppColors.reportCatAid,
  ),
  ReportCategoryStyle(
    category: ReportCategory.alert,
    label: 'Air alert / siren',
    icon: Icons.warning_rounded,
    color: AppColors.reportCatAlert,
  ),
  ReportCategoryStyle(
    category: ReportCategory.displaced,
    label: 'Displaced persons',
    icon: Icons.groups,
    color: AppColors.reportCatDisplaced,
  ),
  ReportCategoryStyle(
    category: ReportCategory.infra,
    label: 'Infrastructure',
    icon: Icons.business,
    color: AppColors.reportCatInfra,
  ),
  ReportCategoryStyle(
    category: ReportCategory.other,
    label: 'Other',
    icon: Icons.more_horiz,
    color: AppColors.reportCatOther,
  ),
];
