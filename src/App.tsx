/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from 'react';
import { FinanceProvider, useFinance } from './context/FinanceContext';
import { Navigation } from './components/Navigation';
import { HomeView } from './components/HomeView';
import { MoneyView } from './components/MoneyView';
import { PlanView } from './components/PlanView';
import { MoneyBucketsView } from './components/MoneyBucketsView';
import { CalendarView } from './components/CalendarView';
import { InsightsView } from './components/InsightsView';
import { AccountsView } from './components/AccountsView';
import { CurrencyView } from './components/CurrencyView';
import { SettingsView } from './components/SettingsView';
import { StudentToolsView } from './components/StudentToolsView';
import { TrendAnalyticsView } from './components/TrendAnalyticsView';
import { CategorizerView } from './components/CategorizerView';
import { RecurringExpensesView } from './components/RecurringExpensesView';
import { ForexTransferAdvisor } from './components/ForexTransferAdvisor';
import { VisaFinancialStatementView } from './components/VisaFinancialStatementView';
import { UpiPaymentsHub } from './components/UpiPaymentsHub';
import { ScanReceiptModal } from './components/modals/ScanReceiptModal';
import { AddTransactionModal } from './components/modals/AddTransactionModal';
import { TransactionDetailModal } from './components/modals/TransactionDetailModal';
import { NavigationTab, Transaction } from './types';
import { Scan, Plus, ShieldCheck, Sparkles } from 'lucide-react';

const MainLayout: React.FC = () => {
  const [currentTab, setCurrentTab] = useState<NavigationTab>('HOME');
  const [isScanReceiptOpen, setIsScanReceiptOpen] = useState(false);
  const [isAddExpenseOpen, setIsAddExpenseOpen] = useState(false);
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null);

  const renderActiveView = () => {
    switch (currentTab) {
      case 'HOME':
        return (
          <HomeView
            onNavigateTab={setCurrentTab}
            onOpenScanReceipt={() => setIsScanReceiptOpen(true)}
            onOpenAddExpense={() => setIsAddExpenseOpen(true)}
            onSelectTransaction={setSelectedTransaction}
          />
        );
      case 'MONEY':
        return (
          <MoneyView
            onSelectTransaction={setSelectedTransaction}
            onOpenAddExpense={() => setIsAddExpenseOpen(true)}
            onOpenScanReceipt={() => setIsScanReceiptOpen(true)}
          />
        );
      case 'PLAN':
        return <PlanView />;
      case 'TRENDS':
        return <TrendAnalyticsView />;
      case 'RECURRING':
        return <RecurringExpensesView />;
      case 'CATEGORIZER':
        return <CategorizerView />;
      case 'STUDENT_TOOLS':
        return <StudentToolsView />;
      case 'BUCKETS':
        return <MoneyBucketsView />;
      case 'CALENDAR':
        return <CalendarView />;
      case 'INSIGHTS':
        return <InsightsView />;
      case 'ACCOUNTS':
        return <AccountsView />;
      case 'CURRENCY':
        return <CurrencyView />;
      case 'FOREX_ADVISOR':
        return <ForexTransferAdvisor />;
      case 'UPI_PAYMENTS':
        return <UpiPaymentsHub />;
      case 'VISA_STATEMENT':
        return <VisaFinancialStatementView />;
      case 'SETTINGS':
        return <SettingsView />;
      default:
        return (
          <HomeView
            onNavigateTab={setCurrentTab}
            onOpenScanReceipt={() => setIsScanReceiptOpen(true)}
            onOpenAddExpense={() => setIsAddExpenseOpen(true)}
            onSelectTransaction={setSelectedTransaction}
          />
        );
    }
  };

  return (
    <div className="min-h-screen bg-slate-100/70 dark:bg-slate-950 text-slate-900 dark:text-slate-100 flex flex-col antialiased transition-colors duration-200">
      {/* Navigation Shell */}
      <Navigation
        currentTab={currentTab}
        onSelectTab={setCurrentTab}
        onOpenScanReceipt={() => setIsScanReceiptOpen(true)}
        onOpenAddExpense={() => setIsAddExpenseOpen(true)}
      >
        <main className="p-3.5 sm:p-6 lg:p-8 max-w-7xl mx-auto w-full">
          {renderActiveView()}
        </main>
      </Navigation>

      {/* Scanned Receipt Modal */}
      <ScanReceiptModal
        isOpen={isScanReceiptOpen}
        onClose={() => setIsScanReceiptOpen(false)}
      />

      {/* Fast Record Modal */}
      <AddTransactionModal
        isOpen={isAddExpenseOpen}
        onClose={() => setIsAddExpenseOpen(false)}
      />

      {/* Transaction Inspection & Detail Modal */}
      <TransactionDetailModal
        transaction={selectedTransaction}
        onClose={() => setSelectedTransaction(null)}
      />
    </div>
  );
};

export default function App() {
  return (
    <FinanceProvider>
      <MainLayout />
    </FinanceProvider>
  );
}
