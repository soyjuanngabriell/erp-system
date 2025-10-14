"use client"

import { Button } from "@/components/ui/button"
import { Download } from "lucide-react"
import jsPDF from "jspdf"
import html2canvas from "html2canvas"

interface PDFGeneratorProps {
  invoiceId: string
  invoiceNumber: string
}

export function PDFGenerator({ invoiceId, invoiceNumber }: PDFGeneratorProps) {
  const generatePDF = async () => {
    try {
      // Fetch invoice data
      const response = await fetch(`/api/invoices/${invoiceId}/pdf`)
      if (!response.ok) {
        throw new Error('Error al cargar la factura')
      }
      
      const htmlContent = await response.text()
      
      // Create a temporary div to render the HTML
      const tempDiv = document.createElement('div')
      tempDiv.innerHTML = htmlContent
      tempDiv.style.position = 'absolute'
      tempDiv.style.left = '-9999px'
      tempDiv.style.top = '0'
      document.body.appendChild(tempDiv)
      
      // Remove the print button from the cloned content
      const printButton = tempDiv.querySelector('.print-button')
      if (printButton) {
        printButton.remove()
      }
      
      // Generate PDF using html2canvas and jsPDF
      const canvas = await html2canvas(tempDiv, {
        scale: 2,
        useCORS: true,
        allowTaint: true,
        backgroundColor: '#ffffff'
      })
      
      const imgData = canvas.toDataURL('image/png')
      const pdf = new jsPDF('p', 'mm', 'a4')
      
      const imgWidth = 210
      const pageHeight = 295
      const imgHeight = (canvas.height * imgWidth) / canvas.width
      let heightLeft = imgHeight
      
      let position = 0
      
      pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight)
      heightLeft -= pageHeight
      
      while (heightLeft >= 0) {
        position = heightLeft - imgHeight
        pdf.addPage()
        pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight)
        heightLeft -= pageHeight
      }
      
      // Clean up
      document.body.removeChild(tempDiv)
      
      // Download the PDF
      pdf.save(`factura-${invoiceNumber}.pdf`)
      
    } catch (error) {
      console.error('Error generating PDF:', error)
      alert('Error al generar el PDF. Por favor, inténtalo de nuevo.')
    }
  }

  return (
    <Button onClick={generatePDF} variant="outline">
      <Download className="mr-2 h-4 w-4" />
      Descargar PDF
    </Button>
  )
}
