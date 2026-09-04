export type CurrencyCode = 
  | 'EUR' 
  | 'INR' 
  | 'USD' 
  | 'GBP' 
  | 'CAD' 
  | 'AUD' 
  | 'JPY' 
  | 'CHF' 
  | 'SGD' 
  | 'AED' 
  | 'NZD' 
  | 'CNY' 
  | 'MYR' 
  | 'BRL' 
  | 'ZAR' 
  | 'SEK' 
  | 'NOK' 
  | 'DKK' 
  | 'PLN' 
  | 'HKD' 
  | 'KRW' 
  | 'THB' 
  | 'TRY' 
  | 'MXN' 
  | 'SAR' 
  | 'QAR' 
  | 'KWD' 
  | 'BHD' 
  | 'OMR' 
  | 'PKR' 
  | 'BDT' 
  | 'LKR' 
  | 'NGN' 
  | 'KES' 
  | 'PHP' 
  | 'IDR' 
  | 'VND' 
  | 'CZK' 
  | 'HUF' 
  | 'ILS' 
  | 'EGP' 
  | 'CLP' 
  | 'COP' 
  | 'PEN' 
  | 'TWD' 
  | 'ARS'
  | (string & {});

export interface WorldCurrency {
  code: CurrencyCode;
  name: string;
  symbol: string;
  flag: string;
  country: string;
  rateVsEur: number;
  decimals: number;
  commonInRemittance?: boolean;
}

export type TransactionType = 'EXPENSE' | 'INCOME' | 'TRANSFER' | 'REFUND' | 'ADJUSTMENT';

export type FinancialIntent = 'NEED' | 'LIFESTYLE' | 'WANT' | 'GOAL';

export type AccountType = 
  | 'IRISH_BANK' 
  | 'REVOLUT' 
  | 'WISE' 
  | 'INDIAN_BANK' 
  | 'FOREX_CARD' 
  | 'CREDIT_CARD' 
  | 'CASH' 
  | 'CUSTOM';

export type BillStatus = 'UPCOMING' | 'DUE' | 'PAID' | 'OVERDUE';

export type BillFrequency = 'ONE_OFF' | 'WEEKLY' | 'BI_WEEKLY' | 'MONTHLY' | 'QUARTERLY' | 'YEARLY';

export type VerificationStatus = 'UNVERIFIED' | 'USER_VERIFIED' | 'SYSTEM_GENERATED' | 'IMPORTED' | 'CORRECTED';

export type RelocationPhase = 'PRE_ARRIVAL' | 'IRELAND_LIVING' | 'ALL' | 'POST_GRADUATION';

export type NavigationTab = 
  | 'HOME' 
  | 'MONEY' 
  | 'PLAN' 
  | 'TRENDS' 
  | 'CATEGORIZER' 
  | 'RECURRING' 
  | 'BUCKETS' 
  | 'CALENDAR' 
  | 'STUDENT_TOOLS' 
  | 'UPI_PAYMENTS'
  | 'INSIGHTS' 
  | 'ACCOUNTS' 
  | 'CURRENCY' 
  | 'SETTINGS'
  | 'VISA_STATEMENT'
  | 'FOREX_ADVISOR';

export interface CategorizationRule {
  id: string;
  keyword: string;
  categoryId: string;
  subcategoryId?: string;
  intent: FinancialIntent;
  phase?: RelocationPhase;
  isActive: boolean;
  matchCount?: number;
}

export interface BudgetAlert {
  id: string;
  type: 'CATEGORY_THRESHOLD' | 'MONTHLY_LIMIT' | 'BURN_RATE' | 'BILL_DUE' | 'LOW_BUFFER' | 'TAX_RELIEF';
  severity: 'INFO' | 'WARNING' | 'CRITICAL';
  title: string;
  message: string;
  thresholdPercent?: number;
  currentAmount?: number;
  targetAmount?: number;
  categoryId?: string;
  actionLabel?: string;
  actionTab?: NavigationTab;
  date: string;
  isRead?: boolean;
  isDismissed?: boolean;
}

export interface AlertSettings {
  enableCategoryAlerts: boolean;
  categoryThresholdPercent: number;
  enableMonthlyLimitAlert: boolean;
  monthlyThresholdPercent: number;
  enableBurnRateAlert: boolean;
  enableBillDueReminder: boolean;
  billReminderDays: number;
  enableLowSpendableAlert: boolean;
  lowSpendableThresholdEur: number;
}

export interface ExchangeRate {
  id: string;
  baseCurrency: CurrencyCode;
  targetCurrency: CurrencyCode;
  rate: number;
  provider: string;
  effectiveDate: string;
  retrievedAt: string;
  status: 'CURRENT' | 'HISTORICAL' | 'STALE' | 'FALLBACK';
}

export interface Account {
  id: string;
  name: string;
  type: AccountType;
  currency: CurrencyCode;
  balance: number;
  institution: string;
  accountNumberMask?: string;
  isPrimary?: boolean;
  notes?: string;
  updatedAt: string;
}

export interface Category {
  id: string;
  name: string;
  iconName: string;
  color: string;
  subcategories: string[];
  isEssential: boolean;
  defaultIntent: FinancialIntent;
  phase: 'BOTH' | 'PRE_ARRIVAL' | 'IRELAND_LIVING';
}

export interface TransactionItem {
  id: string;
  name: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
  currency: CurrencyCode;
  categoryId?: string;
  subcategoryId?: string;
  ocrConfidence?: number;
  categoryConfidence?: number;
}

export interface Transaction {
  id: string;
  type: TransactionType;
  amount: number;
  currency: CurrencyCode;
  historicalExchangeRate: number;
  historicalConvertedAmount: number;
  date: string;
  merchantName: string;
  accountId: string;
  toAccountId?: string;
  categoryId: string;
  subcategoryId?: string;
  intent: FinancialIntent;
  notes?: string;
  receiptId?: string;
  items?: TransactionItem[];
  verificationStatus: VerificationStatus;
  phase: RelocationPhase;
  createdAt: string;
  updatedAt: string;
  recurringId?: string;
  transferId?: string;
  isRefunded?: boolean;
  refundedTransactionId?: string;
}

export interface Receipt {
  id: string;
  transactionId?: string;
  imageData?: string;
  merchant: string;
  date: string;
  currency: CurrencyCode;
  subtotal: number;
  tax: number;
  discount: number;
  total: number;
  ocrConfidence: {
    merchant: number;
    date: number;
    total: number;
    category: number;
    overall: number;
  };
  processingStatus: 'IDLE' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
  items: TransactionItem[];
  rawText?: string;
  warnings?: string[];
}

export interface BudgetCategory {
  categoryId: string;
  planned: number;
  actual: number;
  forecast: number;
  variance: number;
}

export interface MonthlyBudget {
  id: string;
  month: string;
  currency: CurrencyCode;
  plannedIncome: number;
  plannedExpenses: number;
  plannedSavings: number;
  categories: Record<string, BudgetCategory>;
  emergencyBuffer: number;
  createdAt: string;
  updatedAt: string;
}

export interface MoneyBucket {
  id: string;
  name: string;
  target: number;
  allocated: number;
  currency: CurrencyCode;
  deadline?: string;
  category?: string;
  color: string;
  iconName: string;
  status: 'ACTIVE' | 'COMPLETED' | 'PAUSED';
  createdAt: string;
  updatedAt: string;
  notes?: string;
}

export interface SavingsGoal {
  id: string;
  name: string;
  targetAmount: number;
  currentAmount: number;
  currency: CurrencyCode;
  monthlyContribution: number;
  deadline: string;
  category: string;
  color: string;
  iconName: string;
  status: 'IN_PROGRESS' | 'ACHIEVED' | 'PAUSED';
  createdAt: string;
  isSmartAutoSave?: boolean;
  spareChangeRoundUp?: boolean;
  spareChangeMultiplier?: number;
  notes?: string;
  priority?: 'HIGH' | 'MEDIUM' | 'LOW';
}

export interface Bill {
  id: string;
  title: string;
  amount: number;
  currency: CurrencyCode;
  dueDate: string;
  frequency: BillFrequency;
  accountId: string;
  categoryId: string;
  subcategoryId?: string;
  reminderDaysBefore: number;
  status: BillStatus;
  autoDeduct: boolean;
  notes?: string;
  lastPaidDate?: string;
}

export interface FinancialEvent {
  id: string;
  title: string;
  type: 'INCOME' | 'EXPENSE' | 'BILL' | 'SAVINGS' | 'TRANSFER';
  date: string;
  amount: number;
  currency: CurrencyCode;
  accountId: string;
  categoryId?: string;
  status: 'PLANNED' | 'CONFIRMED' | 'PAST_DUE';
  source: 'RECURRING' | 'BILL' | 'MANUAL' | 'GOAL';
  isPositive: boolean;
}

export interface SafeToSpendBreakdown {
  totalMoney: number;
  committedMoney: number;
  availableMoney: number;
  upcomingBills: number;
  remainingEssentials: number;
  plannedSavings: number;
  emergencyBuffer: number;
  safeDiscretionaryTotal: number;
  daysRemaining: number;
  safeDailySpend: number;
  status: 'GREEN' | 'AMBER' | 'RED';
  statusMessage: string;
  assumptions: string[];
}

export interface SpendingVelocity {
  daysElapsed: number;
  daysInMonth: number;
  actualSpent: number;
  expectedSpentByNow: number;
  burnRatePercentage: number;
  projectedMonthEndSpend: number;
  monthlyBudget: number;
  projectedVariance: number;
  status: 'GREEN' | 'AMBER' | 'RED';
}

export interface FinancialInsight {
  id: string;
  type: 'TREND' | 'ANOMALY' | 'BUDGET_PACING' | 'SAVINGS_OPPORTUNITY' | 'FX_ALERT' | 'ACHIEVEMENT';
  title: string;
  description: string;
  severity: 'INFO' | 'SUCCESS' | 'WARNING';
  category?: string;
  metric?: string;
  actionLabel?: string;
  actionPayload?: string;
  createdAt: string;
}

export type ThemeMode = 'light' | 'dark' | 'system';

export interface UserProfile {
  id: string;
  email: string;
  name: string;
  avatarUrl?: string;
  authProvider: 'LOCAL' | 'GOOGLE' | 'GUEST';
  university?: string;
  originCountry?: string;
  destinationCountry?: string;
  primaryCurrency: CurrencyCode;
  createdAt: string;
  lastLoginAt: string;
  hasCustomCredentials?: boolean;
}

export interface AuthSession {
  user: UserProfile | null;
  isAuthenticated: boolean;
  token?: string;
}

export interface DetectedRecurringExpense {
  id: string;
  merchantName: string;
  normalizedMerchant: string;
  frequency: BillFrequency;
  averageAmount: number;
  currency: CurrencyCode;
  occurrences: number;
  intervalDays: number;
  firstSeenDate: string;
  lastSeenDate: string;
  estimatedNextDueDate: string;
  categoryId: string;
  subcategoryId?: string;
  confidenceScore: number;
  isAlreadyTrackedAsBill: boolean;
  linkedBillId?: string;
  sampleTransactionIds: string[];
}

export interface UserPreferences {
  userName: string;
  userEmail?: string;
  originCountry: string;
  destinationCountry: string;
  primaryCurrency: CurrencyCode;
  secondaryCurrencies: CurrencyCode[];
  universityName: string;
  monthStartDay: number;
  activePhase: RelocationPhase;
  hasCompletedOnboarding: boolean;
  theme?: ThemeMode;
}

export interface FinancialState {
  preferences: UserPreferences;
  accounts: Account[];
  transactions: Transaction[];
  receipts: Receipt[];
  budget: MonthlyBudget;
  buckets: MoneyBucket[];
  goals: SavingsGoal[];
  bills: Bill[];
  exchangeRates: ExchangeRate[];
  insights: FinancialInsight[];
  categorizationRules?: CategorizationRule[];
}
