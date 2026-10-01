import json
from flask import Flask, request, render_template_string

app = Flask(__name__)
DATA_FILE = "data.json"

def load_data():
    try:
        with open(DATA_FILE, "r") as f:
            return json.load(f)
    except:
        return {"balance": 0.0, "transactions": []}

def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

HTML = '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>دفتر الحسابات</title>
    <style>
        body { font-family: system-ui, sans-serif; background-color: #f0f2f5; margin: 0; padding: 15px; }
        .card { background: white; max-width: 450px; margin: auto; padding: 20px; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
        h2 { text-align: center; color: #1a1a1a; margin-top: 0; }
        .balance-box { background: #eef2ff; padding: 15px; border-radius: 12px; text-align: center; font-size: 22px; font-weight: bold; color: #3730a3; margin-bottom: 20px; }
        input { width: 100%; padding: 12px; font-size: 16px; border: 1px solid #d1d5db; border-radius: 8px; box-sizing: border-box; margin-bottom: 12px; text-align: center; }
        .btn-group { display: flex; gap: 10px; margin-bottom: 20px; }
        button { flex: 1; padding: 12px; font-size: 16px; border: none; border-radius: 8px; color: white; font-weight: bold; cursor: pointer; }
        .btn-income { background-color: #16a34a; }
        .btn-expense { background-color: #dc2626; }
        .btn-delete { background-color: #ef4444; color: white; border: none; padding: 4px 8px; border-radius: 4px; cursor: pointer; font-size: 12px; }
        ul { list-style: none; padding: 0; margin: 0; }
        li { background: #f9fafb; padding: 10px 12px; margin-bottom: 8px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; }
        .income { border-right: 4px solid #16a34a; }
        .expense { border-right: 4px solid #dc2626; }
    </style>
</head>
<body>
    <div class="card">
        <h2>📱 دفتر الحسابات</h2>
        <div class="balance-box">الرصيد: {{ "%.2f"|format(data.balance) }} $</div>
        
        <form method="POST" action="/add">
            <input type="number" step="any" name="amount" placeholder="أدخل المبلغ" required>
            <div class="btn-group">
                <button type="submit" name="type" value="income" class="btn-income">دخل (+)</button>
                <button type="submit" name="type" value="expense" class="btn-expense">مصروف (-)</button>
            </div>
        </form>

        <h3>سجل العمليات:</h3>
        <ul>
            {% for t in data.transactions %}
                <li class="{{ t.type }}">
                    <span>{{ 'دخل' if t.type == 'income' else 'مصروف' }}: <strong>{{ t.amount }} $</strong></span>
                    <form method="POST" action="/delete/{{ loop.index0 }}" style="margin:0;">
                        <button type="submit" class="btn-delete">حذف</button>
                    </form>
                </li>
            {% endfor %}
        </ul>
    </div>
</body>
</html>
'''

@app.route('/')
def home():
    return render_template_string(HTML, data=load_data())

@app.route('/add', methods=['POST'])
def add():
    data = load_data()
    try:
        amount = float(request.form.get('amount', 0))
        trans_type = request.form.get('type')
        if trans_type == 'income':
            data['balance'] += amount
        else:
            data['balance'] -= amount
        data['transactions'].insert(0, {'amount': amount, 'type': trans_type})
        save_data(data)
    except:
        pass
    return render_template_string(HTML, data=data)

@app.route('/delete/<int:index>', methods=['POST'])
def delete(index):
    data = load_data()
    if 0 <= index < len(data['transactions']):
        t = data['transactions'].pop(index)
        if t['type'] == 'income':
            data['balance'] -= t['amount']
        else:
            data['balance'] += t['amount']
        save_data(data)
    return render_template_string(HTML, data=data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
