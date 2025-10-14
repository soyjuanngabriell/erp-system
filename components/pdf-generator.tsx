"use client"

import { Button } from "@/components/ui/button"
import { Printer } from "lucide-react"

interface PrintButtonProps {
  invoiceId: string
  invoiceNumber: string
}

export function PrintButton({ invoiceId, invoiceNumber }: PrintButtonProps) {
  const printInvoice = async () => {
    try {
      // Fetch invoice data
      const response = await fetch(`/api/invoices/${invoiceId}/pdf`)
      if (!response.ok) {
        throw new Error('Error al cargar la factura')
      }
      
      const htmlContent = await response.text()
      
      // Create a new window for printing
      const printWindow = window.open('', '_blank')
      if (!printWindow) {
        throw new Error('No se pudo abrir la ventana de impresión')
      }
      
      printWindow.document.write(htmlContent)
      printWindow.document.close()
      
      // Wait for content to load then trigger print
      printWindow.onload = () => {
        printWindow.print()
        printWindow.onafterprint = () => {
          printWindow.close()
        }
      }
      
    } catch (error) {
      console.error('Error printing invoice:', error)
      alert('Error al imprimir la factura. Por favor, inténtalo de nuevo.')
    }
  }

  return (
    <Button onClick={printInvoice} variant="outline" size="sm">
      <Printer className="mr-2 h-4 w-4" />
      Imprimir
    </Button>
  )
}
