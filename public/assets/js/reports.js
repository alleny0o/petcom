document.addEventListener("DOMContentLoaded", function() {
  const startDateInput = document.getElementById('start_date');
  const endDateInput = document.getElementById('end_date');
  const resetBtn = document.getElementById('reset-dates');

  // Safety check: Only execute if we are actually on the reports page
  if (startDateInput && endDateInput && resetBtn) {
      
      function setDefaultDates() {
          let today = new Date();
          let lastMonth = new Date();
          lastMonth.setDate(today.getDate() - 30);
          
          endDateInput.valueAsDate = today;
          startDateInput.valueAsDate = lastMonth;
      }

      // Set the default dates on page load
      setDefaultDates();

      // Handle the reset button click
      resetBtn.addEventListener('click', function() {
          setDefaultDates();
          
          // Scope the reset to only select dropdowns inside the report form
          const reportForm = document.getElementById('report-form');
          if (reportForm) {
              reportForm.querySelectorAll('select').forEach(select => {
                  select.value = 'all';
              });
          }
      });
  }
});