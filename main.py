import flet as ft
import json
import os

DATA_FILE = "accounts_data.json"

def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except:
            pass
    return {"clients": [], "transactions": []}

def save_data(data):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def main(page: ft.Page):
    page.title = "دفتر الحسابات"
    page.rtl = True
    page.theme_mode = ft.ThemeMode.LIGHT
    page.padding = 15

    data = load_data()

    # عناصر المدخلات
    client_name_input = ft.TextField(label="اسم الشخص / الحساب", expand=True)
    amount_input = ft.TextField(label="المبلغ", keyboard_type=ft.KeyboardType.NUMBER, expand=True)
    details_input = ft.TextField(label="التفاصيل / البيان", expand=True)
    
    currency_dropdown = ft.Dropdown(
        label="العملة",
        options=[
            ft.dropdown.Option("دولار"),
            ft.dropdown.Option("سعودي"),
            ft.dropdown.Option("محلي"),
        ],
        value="دولار",
        width=120
    )

    client_select_dropdown = ft.Dropdown(label="اختر الحساب / الشخص", expand=True)

    summary_text = ft.Text("إجمالي الحسابات: 0", size=18, weight=ft.FontWeight.BOLD, color=ft.colors.BLUE_900)
    records_list = ft.ListView(expand=True, spacing=8)

    def update_client_dropdown():
        client_select_dropdown.options = [ft.dropdown.Option(c) for c in data["clients"]]
        page.update()

    def calculate_summary():
        total_balance = 0
        for t in data["transactions"]:
            if t["type"] == "give":  # له (دائن)
                total_balance += t["amount"]
            else:  # عليه (مدين)
                total_balance -= t["amount"]
        summary_text.value = f"إجمالي الصافي: {total_balance:,.2f}"

    def render_transactions():
        records_list.controls.clear()
        for idx, t in enumerate(data["transactions"]):
            is_give = t["type"] == "give"
            color = ft.colors.GREEN_700 if is_give else ft.colors.RED_700
            type_label = "له (+)" if is_give else "عليه (-)"

            records_list.controls.append(
                ft.Container(
                    content=ft.ListTile(
                        leading=ft.Icon(
                            ft.icons.ARROW_UPWARD if is_give else ft.icons.ARROW_DOWNWARD,
                            color=color
                        ),
                        title=ft.Text(f"{t['client']} - {t['amount']} {t['currency']}", weight=ft.FontWeight.BOLD),
                        subtitle=ft.Text(f"{t['details']} | {type_label}"),
                        trailing=ft.IconButton(
                            ft.icons.DELETE,
                            icon_color=ft.colors.RED_400,
                            on_click=lambda e, i=idx: delete_transaction(i)
                        )
                    ),
                    border=ft.border.all(1, ft.colors.GREY_300),
                    border_radius=8,
                    bgcolor=ft.colors.WHITE
                )
            )
        calculate_summary()
        page.update()

    def add_client(e):
        name = client_name_input.value.strip()
        if name and name not in data["clients"]:
            data["clients"].append(name)
            save_data(data)
            client_name_input.value = ""
            update_client_dropdown()
            page.show_snack_bar(ft.SnackBar(ft.Text("تمت إضافة الحساب بنجاح!")))

    def add_transaction(is_give):
        if not client_select_dropdown.value or not amount_input.value:
            page.show_snack_bar(ft.SnackBar(ft.Text("يرجى اختيار الحساب وإدخال المبلغ!")))
            return

        try:
            amount = float(amount_input.value)
        except ValueError:
            return

        trans = {
            "client": client_select_dropdown.value,
            "amount": amount,
            "currency": currency_dropdown.value,
            "details": details_input.value or "بدون تفاصيل",
            "type": "give" if is_give else "take"
        }

        data["transactions"].insert(0, trans)
        save_data(data)

        amount_input.value = ""
        details_input.value = ""
        render_transactions()

    def delete_transaction(index):
        if 0 <= index < len(data["transactions"]):
            data["transactions"].pop(index)
            save_data(data)
            render_transactions()

    # تهيئة القوائم والعرض
    update_client_dropdown()

    page.add(
        ft.AppBar(title=ft.Text("دفتر الحسابات Pro"), bgcolor=ft.colors.BLUE_700, color=ft.colors.WHITE),
        ft.Card(
            content=ft.Container(
                content=ft.Column([
                    ft.Text("إضافة شخص / حساب جديد", weight=ft.FontWeight.BOLD),
                    ft.Row([client_name_input, ft.ElevatedButton("إضافة", on_click=add_client)]),
                ]),
                padding=10
            )
        ),
        ft.Card(
            content=ft.Container(
                content=ft.Column([
                    ft.Text("تسجيل عملية كشف حساب", weight=ft.FontWeight.BOLD),
                    ft.Row([client_select_dropdown, currency_dropdown]),
                    details_input,
                    amount_input,
                    ft.Row([
                        ft.ElevatedButton("له (+)", on_click=lambda e: add_transaction(True), bgcolor=ft.colors.GREEN, color=ft.colors.WHITE, expand=True),
                        ft.ElevatedButton("عليه (-)", on_click=lambda e: add_transaction(False), bgcolor=ft.colors.RED, color=ft.colors.WHITE, expand=True),
                    ])
                ]),
                padding=10
            )
        ),
        ft.Divider(),
        summary_text,
        records_list
    )

    render_transactions()

if __name__ == "__main__":
    ft.app(target=main)
