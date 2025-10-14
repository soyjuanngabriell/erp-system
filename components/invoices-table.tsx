"use client"

import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Eye } from "lucide-react"
import Link from "next/link"
import { PDFGenerator } from "@/components/pdf-generator"

interface Invoice {
  id: string
  invoice_number: string
  customer_name: string
  total: number
  created_at: string
}

interface InvoicesTableProps {
  invoices: Invoice[]
}

export function InvoicesTable({ invoices }: InvoicesTableProps) {
  if (invoices.length === 0) {
    return <p className="text-center text-muted-foreground py-8">No hay facturas registradas</p>
  }

  return (
    <div className="rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Número</TableHead>
            <TableHead>Cliente</TableHead>
            <TableHead className="text-right">Total</TableHead>
            <TableHead>Fecha</TableHead>
            <TableHead className="text-right">Acciones</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {invoices.map((invoice) => (
            <TableRow key={invoice.id}>
              <TableCell className="font-medium">{invoice.invoice_number}</TableCell>
              <TableCell>{invoice.customer_name}</TableCell>
              <TableCell className="text-right">RD$ {invoice.total.toLocaleString()}</TableCell>
              <TableCell>{new Date(invoice.created_at).toLocaleDateString("es-DO")}</TableCell>
              <TableCell className="text-right">
                <div className="flex justify-end gap-2">
                  <Button variant="ghost" size="icon" asChild>
                    <Link href={`/dashboard/invoices/${invoice.id}`}>
                      <Eye className="h-4 w-4" />
                    </Link>
                  </Button>
                  <PDFGenerator invoiceId={invoice.id} invoiceNumber={invoice.invoice_number} />
                </div>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}
