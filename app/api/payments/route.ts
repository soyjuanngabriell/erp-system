import { createClient } from "@/lib/supabase/server"
import { NextResponse } from "next/server"

export async function POST(request: Request) {
  try {
    const { order_id, amount, payment_method, notes } = await request.json()

    if (!order_id || !amount || amount <= 0) {
      return NextResponse.json({ 
        success: false, 
        error: "Order ID and amount are required" 
      }, { status: 400 })
    }

    const supabase = await createClient()

    // Get current user
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return NextResponse.json({ 
        success: false, 
        error: "Unauthorized" 
      }, { status: 401 })
    }

    // Verify order exists and get current status
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("*")
      .eq("id", order_id)
      .single()

    if (orderError || !order) {
      return NextResponse.json({ 
        success: false, 
        error: "Order not found" 
      }, { status: 404 })
    }

    // Check if order is already fully paid
    if (order.pending_amount <= 0) {
      return NextResponse.json({ 
        success: false, 
        error: "Order is already fully paid" 
      }, { status: 400 })
    }

    // Check if payment amount exceeds pending amount
    if (amount > order.pending_amount) {
      return NextResponse.json({ 
        success: false, 
        error: `Payment amount cannot exceed pending amount (RD$ ${order.pending_amount.toLocaleString()})` 
      }, { status: 400 })
    }

    // Insert payment record
    const { data: payment, error: paymentError } = await supabase
      .from("order_payments")
      .insert({
        order_id,
        amount,
        payment_method: payment_method || "Efectivo",
        notes: notes || null,
        created_by: user.id,
      })
      .select()
      .single()

    if (paymentError) {
      console.error("[Add Payment] Error:", paymentError)
      return NextResponse.json({ 
        success: false, 
        error: "Error al registrar el pago" 
      }, { status: 500 })
    }

    // The trigger will automatically update the order's payment status
    // But we can also manually trigger it to be sure
    await supabase.rpc("update_order_payment_status", {
      p_order_id: order_id
    })

    // Check if order is now fully paid and completed
    const { data: updatedOrder } = await supabase
      .from("orders")
      .select("*")
      .eq("id", order_id)
      .single()

    let invoiceId = null
    if (updatedOrder && updatedOrder.pending_amount <= 0 && updatedOrder.status === "Completada") {
      // Convert to invoice - ensure invoice_type is passed as string
      const invoiceType = updatedOrder.invoice_type ? String(updatedOrder.invoice_type) : "BASICA"
      const { data: convertedInvoiceId, error: conversionError } = await supabase.rpc("convert_order_to_invoice", {
        p_order_id: order_id,
        p_invoice_type: invoiceType
      })

      if (conversionError) {
        console.error("[Convert to Invoice] Error:", conversionError)
        // Don't fail the payment, just log the error
      } else {
        invoiceId = convertedInvoiceId
      }
    }

    return NextResponse.json({
      success: true,
      data: {
        payment,
        order: updatedOrder,
        invoice_id: invoiceId,
        converted_to_invoice: !!invoiceId
      }
    })
  } catch (error) {
    console.error("[Add Payment] Error:", error)
    return NextResponse.json(
      {
        success: false,
        error: "Error interno del servidor",
      },
      { status: 500 },
    )
  }
}

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const orderId = searchParams.get("order_id")

    if (!orderId) {
      return NextResponse.json({ 
        success: false, 
        error: "Order ID is required" 
      }, { status: 400 })
    }

    const supabase = await createClient()

    // Get payments for the order
    const { data: payments, error } = await supabase
      .from("order_payments")
      .select(`
        *,
        profiles:created_by(full_name)
      `)
      .eq("order_id", orderId)
      .order("payment_date", { ascending: false })

    if (error) {
      console.error("[Get Payments] Error:", error)
      return NextResponse.json({ 
        success: false, 
        error: "Error al obtener los pagos" 
      }, { status: 500 })
    }

    return NextResponse.json({
      success: true,
      data: payments || []
    })
  } catch (error) {
    console.error("[Get Payments] Error:", error)
    return NextResponse.json(
      {
        success: false,
        error: "Error interno del servidor",
      },
      { status: 500 },
    )
  }
}
