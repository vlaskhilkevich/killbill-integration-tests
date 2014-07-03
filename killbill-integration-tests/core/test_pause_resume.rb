$LOAD_PATH.unshift File.expand_path('../..', __FILE__)

require 'test_base'

module KillBillIntegrationTests

  class TestPauseResume < Base

    def setup
      @user = "TestPauseResume"
      setup_base(@user)

      # Create account
      default_time_zone = nil
      @account = create_account(@user, default_time_zone, @options)
      add_payment_method(@account.account_id, '__EXTERNAL_PAYMENT__', true, @user, @options)
      @account = get_account(@account.account_id, false, false, @options)

    end

    def teardown
      teardown_base
    end

    def test_basic

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)


      # Second invoice
      # Move clock  (BP out of trial)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.00, 'USD', "2013-08-31")
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Move clock  and pause bundle
      kb_clock_add_days(5, nil, @options) # 5/09/2013
      pause_bundle(bp.bundle_id, nil, @user, @options)

      # Verify last invoice was adjusted
      wait_for_expected_clause(3, second_invoice.invoice_id, &@proc_invoice_items_nb)

      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 83.33, 'USD', "2013-08-31")
      assert_equal(3, second_invoice.items.size)
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -416.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(second_invoice.items[2], second_invoice.invoice_id, 416.67, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-05')

      # Move clock
      kb_clock_add_days(5, nil, @options) # 10/09/2013
      resume_bundle(bp.bundle_id, nil, @user, @options)

      # Verify last invoice was adjusted
      wait_for_expected_clause(3, @account, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 322.58, 'USD', "2013-09-10")
      assert_equal(2, third_invoice.items.size)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 322.58, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-10', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, -322.58, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')


      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(1, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-01", nil, "2013-08-01", nil)
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                    {:type => "START_BILLING", :date => "2013-08-01"},
                    {:type => "PHASE", :date => "2013-08-31"},
                    {:type => "PAUSE_ENTITLEMENT", :date => "2013-09-05"},
                    {:type => "PAUSE_BILLING", :date => "2013-09-05"},
                    {:type => "RESUME_ENTITLEMENT", :date => "2013-09-10"},
                    {:type => "RESUME_BILLING", :date => "2013-09-10"}], bp.events)

    end



    def test_with_ao

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)


      # Second invoice
      # Move clock  (BP out of trial)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 500.00, 'USD', "2013-08-31")
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')


      # Move clock  and create ao
      # Third invoice : 2/09/2013 -> 30/09/2013
      kb_clock_add_days(2, nil, @options) # 2/09/2013
      ao1 = create_entitlement_ao(bp.bundle_id, 'OilSlick', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-09-02", nil)

      wait_for_expected_clause(3, @account, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 7.18, 'USD', "2013-09-02")
      assert_equal(1, third_invoice.items.size)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 7.18, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-evergreen', '2013-09-02', '2013-09-30')


      # Move clock  and pause bundle
      kb_clock_add_days(3, nil, @options) # 5/09/2013
      pause_bundle(bp.bundle_id, nil, @user, @options)


      # Verify last invoice was adjusted
      wait_for_expected_clause(3, third_invoice.invoice_id, &@proc_invoice_items_nb)
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)

      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 83.33, 'USD', "2013-08-31")
      assert_equal(3, second_invoice.items.size)
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -416.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(second_invoice.items[2], second_invoice.invoice_id, 416.67, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-05')

      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 0.77, 'USD', "2013-09-02")
      assert_equal(3, third_invoice.items.size)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 7.18, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-evergreen', '2013-09-02', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, -6.41, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(third_invoice.items[2], third_invoice.invoice_id, 6.41, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-05')

      # Move clock
      kb_clock_add_days(5, nil, @options) # 10/09/2013
      resume_bundle(bp.bundle_id, nil, @user, @options)

      # Verify last invoice was adjusted
      wait_for_expected_clause(4, @account, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(true, @options)
      assert_equal(4, all_invoices.size)
      sort_invoices!(all_invoices)
      fourth_invoice = all_invoices[3]
      check_invoice_no_balance(fourth_invoice, 327.71, 'USD', "2013-09-10")
      assert_equal(3, fourth_invoice.items.size)
      check_invoice_item(get_specific_invoice_item(fourth_invoice.items, 'RECURRING', 'oilslick-monthly-evergreen'), fourth_invoice.invoice_id, 5.13, 'USD', 'RECURRING', 'oilslick-monthly', 'oilslick-monthly-evergreen', '2013-09-10', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(fourth_invoice.items, 'RECURRING', 'sports-monthly-evergreen'), fourth_invoice.invoice_id, 322.58, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-10', '2013-09-30')
      check_invoice_item(get_specific_invoice_item(fourth_invoice.items, 'CBA_ADJ', nil), fourth_invoice.invoice_id, -327.71, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')


      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(2, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-01", nil, "2013-08-01", nil)
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                    {:type => "START_BILLING", :date => "2013-08-01"},
                    {:type => "PHASE", :date => "2013-08-31"},
                    {:type => "PAUSE_ENTITLEMENT", :date => "2013-09-05"},
                    {:type => "PAUSE_BILLING", :date => "2013-09-05"},
                    {:type => "RESUME_ENTITLEMENT", :date => "2013-09-10"},
                    {:type => "RESUME_BILLING", :date => "2013-09-10"}], bp.events)


      # No DISCOUNT phase as we started he subscription more than a month after BP and this is bundle aligned.
      ao1 = subscriptions.find { |s| s.subscription_id == ao1.subscription_id }
      check_subscription(ao1, 'OilSlick', 'ADD_ON', 'MONTHLY', 'DEFAULT', "2013-09-02", nil, "2013-09-02", nil)
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-09-02"},
                    {:type => "START_BILLING", :date => "2013-09-02"},
                    {:type => "PAUSE_ENTITLEMENT", :date => "2013-09-05"},
                    {:type => "PAUSE_BILLING", :date => "2013-09-05"},
                    {:type => "RESUME_ENTITLEMENT", :date => "2013-09-10"},
                    {:type => "RESUME_BILLING", :date => "2013-09-10"}], ao1.events)


    end


    def test_future_pause

      # First invoice  01/08/2013 -> 31/08/2013 ($0) => BCD = 31
      bp = create_entitlement_base(@account.account_id, 'Sports', 'MONTHLY', 'DEFAULT', @user, @options)
      check_entitlement(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', DEFAULT_KB_INIT_DATE, nil)
      wait_for_expected_clause(1, @account, &@proc_account_invoices_nb)


      # Second invoice
      # Move clock  (BP out of trial)
      kb_clock_add_days(30, nil, @options) # 31/08/2013

      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]

      check_invoice_no_balance(second_invoice, 500.00, 'USD', "2013-08-31")
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')

      # Pause in the future
      pause_bundle(bp.bundle_id, "2013-09-05", @user, @options)

      # Here all we can do is wait; we are waiting to check there is NO change in the system, no nothing to check against
      wait_for_killbill
      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      second_invoice = all_invoices[1]
      assert_equal(1, second_invoice.items.size)

      # Check the subscription is marked as PAUSED in the future
      subscriptions = get_subscriptions(bp.bundle_id, @options)
      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-01", nil, "2013-08-01", nil)
=begin
      # BUG : futre pause events are not returned
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                    {:type => "START_BILLING", :date => "2013-08-01"},
                    {:type => "PHASE", :date => "2013-08-31"},
                    {:type => "PAUSE_ENTITLEMENT", :date => "2013-09-05"},
                    {:type => "PAUSE_BILLING", :date => "2013-09-05"}], bp.events)
=end
      # Move clock to reach pause
      kb_clock_add_days(5, nil, @options) # 5/09/2013

      all_invoices = @account.invoices(true, @options)
      assert_equal(2, all_invoices.size)
      sort_invoices!(all_invoices)
      second_invoice = all_invoices[1]
      check_invoice_no_balance(second_invoice, 83.33, 'USD', "2013-08-31")
      assert_equal(3, second_invoice.items.size)
      check_invoice_item(second_invoice.items[0], second_invoice.invoice_id, 500.00, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-08-31', '2013-09-30')
      check_invoice_item(second_invoice.items[1], second_invoice.invoice_id, -416.67, 'USD', 'REPAIR_ADJ', nil, nil, '2013-09-05', '2013-09-30')
      check_invoice_item(second_invoice.items[2], second_invoice.invoice_id, 416.67, 'USD', 'CBA_ADJ', nil, nil, '2013-09-05', '2013-09-05')

      # Move clock
      kb_clock_add_days(5, nil, @options) # 10/09/2013
      resume_bundle(bp.bundle_id, nil, @user, @options)

      # Verify last invoice was adjusted
      wait_for_expected_clause(3, @account, &@proc_account_invoices_nb)
      all_invoices = @account.invoices(true, @options)
      assert_equal(3, all_invoices.size)
      sort_invoices!(all_invoices)
      third_invoice = all_invoices[2]
      check_invoice_no_balance(third_invoice, 322.58, 'USD', "2013-09-10")
      assert_equal(2, third_invoice.items.size)
      check_invoice_item(third_invoice.items[0], third_invoice.invoice_id, 322.58, 'USD', 'RECURRING', 'sports-monthly', 'sports-monthly-evergreen', '2013-09-10', '2013-09-30')
      check_invoice_item(third_invoice.items[1], third_invoice.invoice_id, -322.58, 'USD', 'CBA_ADJ', nil, nil, '2013-09-10', '2013-09-10')


      subscriptions = get_subscriptions(bp.bundle_id, @options)
      assert_not_nil(subscriptions)
      assert_equal(1, subscriptions.size)

      bp = subscriptions.find { |s| s.subscription_id == bp.subscription_id }
      check_subscription(bp, 'Sports', 'BASE', 'MONTHLY', 'DEFAULT', "2013-08-01", nil, "2013-08-01", nil)
      check_events([{:type => "START_ENTITLEMENT", :date => "2013-08-01"},
                    {:type => "START_BILLING", :date => "2013-08-01"},
                    {:type => "PHASE", :date => "2013-08-31"},
                    {:type => "PAUSE_ENTITLEMENT", :date => "2013-09-05"},
                    {:type => "PAUSE_BILLING", :date => "2013-09-05"},
                    {:type => "RESUME_ENTITLEMENT", :date => "2013-09-10"},
                    {:type => "RESUME_BILLING", :date => "2013-09-10"}], bp.events)

    end



    private

    def get_specific_invoice_item(items, type, phase_name)
      items.each do |i|
        if i.phase_name == phase_name && i.item_type == type
          return i
        end
      end
      nil
    end

  end
end
