from django.shortcuts import render

def index(request, testo="Hello World"):
    return render(request, 'index.html', {'testo': testo})