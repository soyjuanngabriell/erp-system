"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { UserPlus } from "lucide-react"
import { createClient } from "@/lib/supabase/client"
import { toast } from "sonner"

interface AssignOrderModalProps {
  orderId: string
  orderTotal: number
  onOrderAssigned: () => void
}

export function AssignOrderModal({ orderId, orderTotal, onOrderAssigned }: AssignOrderModalProps) {
  const [open, setOpen] = useState(false)
  const [assigning, setAssigning] = useState(false)
  const [depositType, setDepositType] = useState<"percentage" | "amount" | "full">("full")
  const [depositValue, setDepositValue] = useState("")
  const supabase = createClient()

  const handleAssign = async () => {
    try {
      setAssigning(true)
      
      let depositAmount = 0
      let depositPercentage = 0
      let paymentStatus = "paid"

      if (depositType === "percentage") {
        depositPercentage = parseFloat(depositValue)
        depositAmount = (orderTotal * depositPercentage) / 100
        paymentStatus = depositPercentage < 100 ? "partial" : "paid"
      } else if (depositType === "amount") {
        depositAmount = parseFloat(depositValue)
        depositPercentage = (depositAmount / orderTotal) * 100
        paymentStatus = depositAmount < orderTotal ? "partial" : "paid"
      } else {
        depositAmount = orderTotal
        depositPercentage = 100
        paymentStatus = "paid"
      }

      const { error } = await supabase
        .from("orders")
        .update({
          assigned_to: (await supabase.auth.getUser()).data.user?.id,
          assigned_at: new Date().toISOString(),
          status: "En Proceso",
          deposit_amount: depositAmount,
          deposit_percentage: depositPercentage,
          payment_status: paymentStatus,
          updated_at: new Date().toISOString()
        })
        .eq("id", orderId)

      if (error) {
        throw error
      }

      toast.success("Orden asignada exitosamente")
      setOpen(false)
      onOrderAssigned()
    } catch (error) {
      console.error("Error assigning order:", error)
      toast.error("Error al asignar la orden")
    } finally {
      setAssigning(false)
    }
  }

  const getDepositLabel = () => {
    switch (depositType) {
      case "percentage":
        return "Porcentaje de abono (%)"
      case "amount":
        return "Monto de abono (RD$)"
      case "full":
        return "Pago completo"
      default:
        return ""
    }
  }

  const getDepositPreview = () => {
    if (depositType === "full") {
      return `RD$ ${orderTotal.toLocaleString()} (100%)`
    }
    
    if (depositValue) {
      const value = parseFloat(depositValue)
      if (depositType === "percentage") {
        const amount = (orderTotal * value) / 100
        return `RD$ ${amount.toLocaleString()} (${value}%)`
      } else {
        const percentage = (value / orderTotal) * 100
        return `RD$ ${value.toLocaleString()} (${percentage.toFixed(1)}%)`
      }
    }
    
    return ""
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          <UserPlus className="mr-2 h-4 w-4" />
          Tomar Orden
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Tomar Orden</DialogTitle>
        </DialogHeader>
        <div className="space-y-4">
          <div className="p-3 bg-muted rounded-lg">
            <p className="text-sm text-muted-foreground">Total de la orden:</p>
            <p className="text-lg font-semibold">RD$ {orderTotal.toLocaleString()}</p>
          </div>
          
          <div className="space-y-2">
            <Label>Tipo de abono</Label>
            <Select value={depositType} onValueChange={(value: "percentage" | "amount" | "full") => setDepositType(value)}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="full">Pago completo (100%)</SelectItem>
                <SelectItem value="percentage">Abono por porcentaje</SelectItem>
                <SelectItem value="amount">Abono por monto</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {depositType !== "full" && (
            <div className="space-y-2">
              <Label htmlFor="depositValue">{getDepositLabel()}</Label>
              <Input
                id="depositValue"
                type="number"
                value={depositValue}
                onChange={(e) => setDepositValue(e.target.value)}
                placeholder={depositType === "percentage" ? "50" : "1000"}
                min="0"
                max={depositType === "percentage" ? "100" : orderTotal}
                step={depositType === "percentage" ? "0.1" : "0.01"}
              />
            </div>
          )}

          {getDepositPreview() && (
            <div className="p-3 bg-blue-50 rounded-lg">
              <p className="text-sm text-blue-700">
                <strong>Resumen:</strong> {getDepositPreview()}
              </p>
            </div>
          )}

          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancelar
            </Button>
            <Button onClick={handleAssign} disabled={assigning || (depositType !== "full" && !depositValue)}>
              {assigning ? "Asignando..." : "Tomar Orden"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
