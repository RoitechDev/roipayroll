/// Nigerian PAYE Tax Calculator (2024/2025 rates)
class TaxCalculatorService {
  // Calculate monthly PAYE tax
  static double calculatePAYE(double annualIncome) {
    double tax = 0;
    
    // Tax-free allowance: First ₦300,000 + 20% of gross income (or ₦200,000, whichever is higher)
    double relief = 300000 + (annualIncome * 0.01).clamp(200000, double.infinity);
    double taxableIncome = (annualIncome - relief).clamp(0, double.infinity);
    
    // Nigerian Tax Brackets (2024)
    if (taxableIncome <= 300000) {
      tax = taxableIncome * 0.07; // 7%
    } else if (taxableIncome <= 600000) {
      tax = (300000 * 0.07) + ((taxableIncome - 300000) * 0.11); // 11%
    } else if (taxableIncome <= 1100000) {
      tax = (300000 * 0.07) + (300000 * 0.11) + ((taxableIncome - 600000) * 0.15); // 15%
    } else if (taxableIncome <= 1600000) {
      tax = (300000 * 0.07) + (300000 * 0.11) + (500000 * 0.15) + ((taxableIncome - 1100000) * 0.19); // 19%
    } else if (taxableIncome <= 3200000) {
      tax = (300000 * 0.07) + (300000 * 0.11) + (500000 * 0.15) + (500000 * 0.19) + ((taxableIncome - 1600000) * 0.21); // 21%
    } else {
      tax = (300000 * 0.07) + (300000 * 0.11) + (500000 * 0.15) + (500000 * 0.19) + (1600000 * 0.21) + ((taxableIncome - 3200000) * 0.24); // 24%
    }
    
    return tax / 12; // Monthly tax
  }
  
  // Calculate Pension (8% employee contribution)
  static double calculatePension(double monthlyGross) {
    return monthlyGross * 0.08;
  }
  
  // Calculate NHF (2.5% of basic salary)
  static double calculateNHF(double monthlyBasic) {
    return monthlyBasic * 0.025;
  }
  
  // Calculate total deductions
  static Map<String, double> calculateDeductions(double monthlyBasic, double monthlyGross) {
    double annualGross = monthlyGross * 12;
    double paye = calculatePAYE(annualGross);
    double pension = calculatePension(monthlyGross);
    double nhf = calculateNHF(monthlyBasic);
    
    return {
      'paye': paye,
      'pension': pension,
      'nhf': nhf,
      'total': paye + pension + nhf,
    };
  }
  
  // Calculate net salary
  static double calculateNetSalary(double grossSalary, Map<String, double> deductions) {
    return grossSalary - deductions['total']!;
  }
}
