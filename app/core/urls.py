from django.urls import path
from testsite.views import index

urlpatterns = [
    path('', index, name='index'),

    path('<str:testo>/', index, name='dynamic_home'),
]