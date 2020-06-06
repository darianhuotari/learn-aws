import os

from flask import Flask, render_template, request
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy


database_uri = 'postgresql+psycopg2://{dbuser}:{dbpass}@{dbhost}/{dbname}'.format(
    dbuser='postgres',
    dbpass='psqlPassword-01',
    dbhost='fotd-postgres.cgmc4zajyzqg.us-east-2.rds.amazonaws.com',
    dbname='postgres'
)

app = Flask(__name__)
app.config.update(
    SQLALCHEMY_DATABASE_URI=database_uri,
    SQLALCHEMY_TRACK_MODIFICATIONS=False,
)

# initialize the database connection
db = SQLAlchemy(app)

# initialize database migration management
migrate = Migrate(app, db)


@app.route('/')
def view_registered_guests():
    from models import Guest
    guests = Guest.query.all()
    return render_template('guest_list.html', guests=guests)


@app.route('/register', methods=['GET'])
def view_registration_form():
    return render_template('guest_registration.html')


@app.route('/register', methods=['POST'])
def register_guest():
    from models import Guest
    name = request.form.get('name')
    email = request.form.get('email')

    guest = Guest(name, email)
    db.session.add(guest)
    db.session.commit()

    return render_template(
        'guest_confirmation.html', name=name, email=email)

if __name__ = '__main__':
    app.config['DEBUG'] = True
    app.run("0.0.0.0", "5000")
