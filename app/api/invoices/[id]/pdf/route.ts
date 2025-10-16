import { NextRequest, NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const supabase = await createClient()

    // Get invoice data
    const { data: invoice } = await supabase
      .from("invoices")
      .select(`
        *,
        invoice_items (*)
      `)
      .eq("id", id)
      .single()

    if (!invoice) {
      return NextResponse.json({ error: "Invoice not found" }, { status: 404 })
    }

    // Get business configuration
    const { data: businessConfig } = await supabase
      .from("business_config")
      .select("*")
      .single()

    // Generate HTML for PDF
    const html = generateInvoiceHTML(invoice, businessConfig)

    // Return HTML that can be printed as PDF by the browser
    return new NextResponse(html, {
      headers: {
        'Content-Type': 'text/html',
        'Content-Disposition': `inline; filename="factura-${invoice.invoice_number}.html"`
      }
    })

  } catch (error) {
    console.error('Error generating PDF:', error)
    return NextResponse.json(
      { error: "Error generating PDF" },
      { status: 500 }
    )
  }
}

function generateInvoiceHTML(invoice: any, businessConfig: any) {
  const formatDate = (date: string) => {
    return new Date(date).toLocaleDateString('es-DO', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    })
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('es-DO', {
      style: 'currency',
      currency: 'DOP',
      minimumFractionDigits: 2
    }).format(amount)
  }

  const getInvoiceTitle = (invoiceType: string) => {
    switch (invoiceType) {
      case 'BASICA':
        return 'FACTURA BÁSICA'
      case 'VALOR_FISCAL':
        return 'FACTURA CON VALOR FISCAL'
      case 'VALOR_GUBERNAMENTAL':
        return 'FACTURA CON VALOR GUBERNAMENTAL'
      default:
        return 'FACTURA'
    }
  }

  const getInvoiceTypeLabel = (invoiceType: string) => {
    switch (invoiceType) {
      case 'VALOR_FISCAL':
        return 'Valor Fiscal'
      case 'VALOR_GUBERNAMENTAL':
        return 'Valor Gubernamental'
      default:
        return ''
    }
  }

  return `
  <!DOCTYPE html>
  <html lang="es">
  <head>
    <meta charset="UTF-8">
    <title>Factura ${invoice.invoice_number}</title>
    <style>
      * {
        box-sizing: border-box;
      }
      body {
        font-family: Arial, sans-serif;
        font-size: 12px;
        color: #000;
        margin: 0;
        padding: 20px;
        background: #f5f5f5;
      }
      .print-button {
        position: fixed;
        top: 20px;
        right: 20px;
        background: #007bff;
        color: white;
        border: none;
        padding: 10px 20px;
        border-radius: 5px;
        cursor: pointer;
        font-size: 14px;
        z-index: 1000;
      }
      .print-button:hover {
        background: #0056b3;
      }
      @media print {
        .print-button {
          display: none;
        }
        body {
          background: white;
          padding: 0;
        }
      }
      .container {
        width: 750px;
        margin: 0 auto;
        padding: 20px;
        background: white;
        box-shadow: 0 0 10px rgba(0,0,0,0.1);
      }
      @media print {
        .container {
          box-shadow: none;
          width: 100%;
          max-width: none;
        }
      }
      .header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        border-bottom: 2px solid #000;
        padding-bottom: 10px;
        margin-bottom: 10px;
      }
      .header-left {
        max-width: 60%;
      }
      .header-left h1 {
        font-size: 20px;
        margin-bottom: 5px;
      }
      .header-left p {
        margin: 2px 0;
        font-size: 11px;
      }
      .header-right {
        text-align: right;
        font-size: 11px;
      }
      .header-right h2 {
        margin: 0;
        font-size: 18px;
      }
      .info-blocks {
        display: flex;
        justify-content: space-between;
        margin-bottom: 10px;
        font-size: 11px;
      }
      .info-left {
        width: 60%;
      }
      .info-left p {
        margin: 2px 0;
      }
      .info-right {
        width: 38%;
        border: 1px solid #000;
        padding: 5px;
      }
      .info-right p {
        margin: 2px 0;
      }
      .items-table {
        width: 100%;
        border-collapse: collapse;
        margin-top: 10px;
        font-size: 11px;
      }
      .items-table th,
      .items-table td {
        border: 1px solid #000;
        padding: 6px;
      }
      .items-table th {
        background: #f0f0f0;
        text-align: center;
      }
      .text-right { text-align: right; }
      .text-center { text-align: center; }
      .totals-section {
        margin-top: 10px;
        width: 250px;
        margin-left: auto;
        font-size: 11px;
      }
      .totals-table {
        width: 100%;
        border-collapse: collapse;
      }
      .totals-table td {
        padding: 4px;
        border: none;
      }
      .totals-table .label {
        text-align: right;
        font-weight: bold;
      }
      .totals-table .total-row {
        background: #f0f0f0;
        font-weight: bold;
        border-top: 1px solid #000;
        border-bottom: 1px solid #000;
      }
      .signatures {
        display: flex;
        justify-content: space-between;
        margin-top: 30px;
        font-size: 11px;
      }
      .signature-box {
        width: 45%;
        border-top: 1px solid #000;
        text-align: center;
        padding-top: 5px;
      }
      .footer {
        margin-top: 20px;
        text-align: center;
        font-size: 11px;
      }
    </style>
  </head>
  <body>
    <button class="print-button" onclick="window.print()">Imprimir PDF</button>
    <div class="container">

      <!-- ENCABEZADO -->
      <div class="header">
        <div class="header-left">
          <h1>${businessConfig?.business_name || 'Nombre de Empresa'}</h1>
          <p>${businessConfig?.address || 'Dirección de la empresa'}</p>
          <p>Tel.: ${businessConfig?.phone || '---'} / RNC: ${businessConfig?.rnc || '---'}</p>
          <p>Email: ${businessConfig?.email || ''}</p>
        </div>
        <div class="header-right">
          <h2>${getInvoiceTitle(invoice.invoice_type)}</h2>
          ${invoice.ncf ? `<p><strong>NCF:</strong> ${invoice.ncf}</p>` : ''}
          <p><strong>Fecha de factura:</strong> ${formatDate(invoice.created_at)}</p>
          <p><strong>Factura #:</strong> ${invoice.invoice_number}</p>
          ${invoice.invoice_type !== 'BASICA' ? `<p><strong>Tipo:</strong> ${getInvoiceTypeLabel(invoice.invoice_type)}</p>` : ''}
        </div>
      </div>

      <!-- BLOQUES DE INFORMACIÓN -->
      <div class="info-blocks">
        <div class="info-left">
          <p><strong>VENDIDO A:</strong> ${invoice.customer_name}</p>
          ${invoice.customer_rnc ? `<p><strong>RNC:</strong> ${invoice.customer_rnc}</p>` : ''}
          ${invoice.customer_address ? `<p><strong>Dirección:</strong> ${invoice.customer_address}</p>` : ''}
        </div>
        <div class="info-right">
          <p><strong>Términos:</strong> ${invoice.payment_method}</p>
          <p><strong>Fecha de vencimiento:</strong> ${invoice.due_date ? formatDate(invoice.due_date) : '---'}</p>
          <p><strong>Vendedor:</strong> ${invoice.sales_rep || '---'}</p>
        </div>
      </div>

      <!-- TABLA DE ITEMS -->
      <table class="items-table">
        <thead>
          <tr>
            <th>CANTIDAD</th>
            <th>DESCRIPCIÓN</th>
            <th>PRECIO UNIT. RD$</th>
            <th>ITBIS RD$</th>
            <th>TOTAL RD$</th>
          </tr>
        </thead>
        <tbody>
          ${invoice.invoice_items?.map((item: any) => `
            <tr>
              <td class="text-center">${item.quantity}</td>
              <td>${item.product_name}</td>
              <td class="text-right">${formatCurrency(item.unit_price)}</td>
              <td class="text-right">${formatCurrency(item.tax_amount || 0)}</td>
              <td class="text-right">${formatCurrency(item.total)}</td>
            </tr>
          `).join('') || ''}
        </tbody>
      </table>

      <!-- TOTALES -->
      <div class="totals-section">
        <table class="totals-table">
          <tr>
            <td class="label">Subtotal:</td>
            <td class="text-right">${formatCurrency(invoice.subtotal)}</td>
          </tr>
          <tr>
            <td class="label">Impuesto 18%:</td>
            <td class="text-right">${formatCurrency(invoice.tax)}</td>
          </tr>
          ${invoice.discount > 0 ? `
          <tr>
            <td class="label">Descuento:</td>
            <td class="text-right">-${formatCurrency(invoice.discount)}</td>
          </tr>
          ` : ''}
          <tr class="total-row">
            <td class="label">TOTAL:</td>
            <td class="text-right">${formatCurrency(invoice.total)}</td>
          </tr>
        </table>
      </div>

      <!-- FIRMAS -->
      <div class="signatures">
        <div class="signature-box">Autorizado por:</div>
        <div class="signature-box">Recibido por:</div>
      </div>

      <div class="footer">
        <p>GRACIAS POR PERMITIRNOS SERVIRLES</p>
      </div>

    </div>
  </body>
  </html>
  `
}
