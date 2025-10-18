"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
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
  const supabase = createClient()

  const handleAssign = async () => {
    try {
      setAssigning(true)
      
      const { error } = await supabase
        .from("orders")
        .update({
          assigned_to: (await supabase.auth.getUser()).data.user?.id,
          assigned_at: new Date().toISOString(),
          status: "En Proceso",
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

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          <UserPlus className="h-4 w-4 mr-2" />
          Tomar Orden
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Tomar Orden</DialogTitle>
        </DialogHeader>
        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">
            ¿Estás seguro de que quieres tomar esta orden? Se cambiará el estado a "En Proceso".
          </p>
          
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancelar
            </Button>
            <Button onClick={handleAssign} disabled={assigning}>
              {assigning ? "Asignando..." : "Tomar Orden"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}