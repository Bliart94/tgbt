import os
import smtplib
from email.message import EmailMessage

def send_order_mail(to_email: str, article_name: str):
    host = os.getenv("SMTP_HOST", "")
    port = int(os.getenv("SMTP_PORT", "587"))
    user = os.getenv("SMTP_USER", "")
    pwd = os.getenv("SMTP_PASS", "")
    mail_from = os.getenv("MAIL_FROM", user)

    if not (host and user and pwd):
        return

    msg = EmailMessage()
    msg["From"] = mail_from
    msg["To"] = to_email
    msg["Subject"] = "Confirmation de commande – TBGT Records"
    msg.set_content(
        f"Bonjour,\n\n"
        f"Votre commande a bien été prise en compte.\n\n"
        f"Article commandé : {article_name}\n\n"
        f"Merci,\nTBGT Records\n"
    )

    with smtplib.SMTP(host, port) as server:
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(user, pwd)
        server.send_message(msg)
