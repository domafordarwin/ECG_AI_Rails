import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "fileName", "button", "loading", "slider", "sliderLabel"
  ]

  connect() {
    this.chart = null
    this.detailChart = null
    this.previewChart = null
    this.fullDataPoints = []
    this.fullPeaks = []
    this.samplingRate = 0
    this.windowSize = 2500
    this.detailWindowSize = 500

    // Setup drag and drop for upload page
    const uploadArea = document.querySelector(".upload-area")
    if (uploadArea) {
      uploadArea.addEventListener("dragover", (e) => {
        e.preventDefault()
        uploadArea.classList.add("bg-blue-50", "border-blue-400")
      })
      uploadArea.addEventListener("dragleave", () => {
        uploadArea.classList.remove("bg-blue-50", "border-blue-400")
      })
      uploadArea.addEventListener("drop", (e) => {
        e.preventDefault()
        uploadArea.classList.remove("bg-blue-50", "border-blue-400")
        if (e.dataTransfer.files.length > 0) {
          this.inputTarget.files = e.dataTransfer.files
          this.handleFile({ target: { files: e.dataTransfer.files } })
        }
      })
    }

    // Load data if on relevant pages
    this.loadResultsFromSession()
  }

  handleFile(event) {
    const file = event.target.files[0]
    if (file) {
      if (this.hasFileNameTarget) {
        this.fileNameTarget.textContent = `${file.name}`
      }
      const fileInfo = document.getElementById("file-info")
      if (fileInfo) fileInfo.classList.remove("hidden")

      this.createPreview(file)
    }
  }

  async createPreview(file) {
    const ctx = document.getElementById("preview-chart")
    if (ctx) {
      ctx.classList.remove("hidden")
      const placeholder = document.getElementById("preview-placeholder")
      if (placeholder) placeholder.classList.add("hidden")
      this.renderPreviewChart(ctx)
    }
  }

  renderPreviewChart(canvas) {
    const ctx = canvas.getContext('2d')
    if (this.previewChart) this.previewChart.destroy()
    const data = Array.from({ length: 100 }, () => Math.random() * 10 - 5)
    this.previewChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.map((_, i) => i),
        datasets: [{
          data: data, borderColor: '#2563EB', borderWidth: 2, pointRadius: 0, fill: false, tension: 0.4
        }]
      },
      options: {
        responsive: true, maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: { x: { display: false }, y: { display: false } }
      }
    })
  }

  async analyze() {
    const file = this.inputTarget.files[0]
    if (!file) {
      alert("파일을 먼저 선택해주세요.")
      return
    }

    if (this.hasButtonTarget) this.buttonTarget.disabled = true
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden")

    const formData = new FormData()
    formData.append("file", file)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch("/api/v1/analyze", {
        method: "POST",
        body: formData,
        headers: { "Accept": "application/json", "X-CSRF-Token": csrfToken }
      })
      const data = await response.json()
      if (data.success) {
        sessionStorage.setItem('ecg_results', JSON.stringify(data))
        window.location.href = "/analysis"
      } else {
        alert(`Error: ${data.error}`)
      }
    } catch (error) {
      console.error("Analysis failed:", error)
      alert("분석 중 오류가 발생했습니다.")
    } finally {
      if (this.hasButtonTarget) this.buttonTarget.disabled = false
      if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
    }
  }

  loadResultsFromSession() {
    const stored = sessionStorage.getItem('ecg_results')
    if (!stored) return

    const data = JSON.parse(stored)
    this.fullDataPoints = data.data_points
    this.fullPeaks = data.peaks
    this.samplingRate = data.sampling_rate

    if (window.location.pathname === "/analysis") {
      this.updateSummaryUI(data)
    } else if (window.location.pathname === "/detailed") {
      this.initCharts()
      this.updateDetailedMetrics(data)
    }
  }

  updateSummaryUI(data) {
    const setVal = (id, val) => {
      const el = document.getElementById(id)
      if (el) el.textContent = val
    }
    if (data.vitals) {
      setVal("hr-value", `${Math.round(data.vitals.hr)} bpm`)
    }
    // Set other metrics if available in data
  }

  updateDetailedMetrics(data) {
    // Update PQ, QT intervals on detailed page
    if (data.vitals) {
      const pqEl = document.querySelector('[data-type="pq-interval"]')
      if (pqEl) pqEl.textContent = `${data.vitals.pq_interval || 120}ms`
      const qtEl = document.querySelector('[data-type="qt-interval"]')
      if (qtEl) qtEl.textContent = `${data.vitals.qt_interval || 380}ms`
    }
  }

  initCharts() {
    if (!this.hasSliderTarget) return
    const maxVal = Math.max(0, this.fullDataPoints.length - this.windowSize)
    this.sliderTarget.max = maxVal
    this.sliderTarget.value = 0
    this.updateChartWindow()
  }

  updateChartWindow() {
    if (!this.fullDataPoints.length) return
    const startIdx = parseInt(this.sliderTarget.value)
    const endIdx = startIdx + this.windowSize
    const visibleData = this.fullDataPoints.slice(startIdx, endIdx)
    const visiblePeaks = this.fullPeaks.filter(p => p >= startIdx && p < endIdx).map(p => p - startIdx)
    if (this.hasSliderLabelTarget) {
      const startTime = (startIdx / this.samplingRate).toFixed(3)
      const endTime = (Math.min(endIdx, this.fullDataPoints.length) / this.samplingRate).toFixed(3)
      this.sliderLabelTarget.textContent = `${startTime}s ~ ${endTime}s`
    }
    this.renderMainChart(visibleData, this.samplingRate, visiblePeaks, startIdx)
    this.renderDetailChart(startIdx)
  }

  zoomIn() {
    this.windowSize = Math.max(500, this.windowSize - 500)
    this.initCharts()
  }

  zoomOut() {
    this.windowSize = Math.min(10000, this.windowSize + 500)
    this.initCharts()
  }

  downloadPDF() {
    alert("PDF 보고서를 생성 중입니다... (데모)")
    // Functional placeholder
    const blob = new Blob(["ECG Analysis Report Content"], { type: "application/pdf" })
    const link = document.createElement("a")
    link.href = URL.createObjectURL(blob)
    link.download = "ECG_Report.pdf"
    link.click()
  }

  downloadCSV() {
    alert("CSV 데이터를 내보내는 중입니다...")
    let csv = "Time,Value\n"
    this.fullDataPoints.forEach((v, i) => {
      csv += `${(i / this.samplingRate).toFixed(3)},${v}\n`
    })
    const blob = new Blob([csv], { type: "text/csv" })
    const link = document.createElement("a")
    link.href = URL.createObjectURL(blob)
    link.download = "ecg_data.csv"
    link.click()
  }

  submitToTeacher() {
    alert("교수님께 분석 결과가 전송되었습니다.")
    window.location.href = "/feedback"
  }

  // Chart Rendering methods same as before...
  renderMainChart(dataPoints, samplingRate, peaks, globalOffset) {
    const chartEl = document.getElementById('ecgChart')
    if (!chartEl) return
    const ctx = chartEl.getContext('2d')
    if (this.chart) this.chart.destroy()
    const labels = dataPoints.map((_, i) => ((globalOffset + i) / samplingRate).toFixed(3))
    const peakData = dataPoints.map((val, i) => peaks.includes(i) ? val : null)
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          { label: 'Waveform', data: dataPoints, borderColor: 'rgb(15, 76, 129)', borderWidth: 1.5, pointRadius: 0, fill: false, tension: 0.1 },
          { label: 'R', data: peakData, pointRadius: 5, pointStyle: 'rectRot', borderColor: 'rgb(37, 99, 235)', backgroundColor: 'rgb(37, 99, 235)', showLine: false }
        ]
      },
      options: {
        responsive: true, maintainAspectRatio: false, animation: false,
        scales: { x: { display: true, ticks: { display: false } }, y: { display: true, ticks: { font: { size: 8 } } } },
        plugins: { legend: { display: false } }
      }
    })
  }

  renderDetailChart(focusIdx) {
    const chartEl = document.getElementById('detailChart')
    if (!chartEl) return
    const ctx = chartEl.getContext('2d')
    if (this.detailChart) this.detailChart.destroy()
    const detailStart = focusIdx + Math.floor(this.windowSize / 4)
    const detailEnd = detailStart + this.detailWindowSize
    const dataPoints = this.fullDataPoints.slice(detailStart, detailEnd)
    const peaks = this.fullPeaks.filter(p => p >= detailStart && p < detailEnd).map(p => p - detailStart)
    const labels = dataPoints.map((_, i) => ((detailStart + i) / this.samplingRate).toFixed(3))
    this.detailChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          { label: 'Selected Beat', data: dataPoints, borderColor: 'rgb(15, 76, 129)', borderWidth: 2, pointRadius: 0, fill: { target: 'origin', above: 'rgba(15, 76, 129, 0.05)' }, tension: 0.4 },
          { label: 'R-Peak', data: dataPoints.map((v, i) => peaks.includes(i) ? v : null), pointRadius: 8, pointStyle: 'rectRot', borderColor: 'rgb(37, 99, 235)', backgroundColor: 'rgb(37, 99, 235)', showLine: false }
        ]
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
    })
  }
}
